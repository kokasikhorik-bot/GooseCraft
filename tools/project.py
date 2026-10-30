"""Build/test entry point, identical on Linux and Windows x64."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import struct
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WINDOWS = sys.platform == "win32"
EXT = ".exe" if WINDOWS else ""
GOOSE = ROOT / ".cache/toolchain/build" / ("Release/goose.exe" if WINDOWS else "goose")
BUILD = ROOT / "build"
CLIENT = BUILD / ("goosecraft-headless" + EXT)
VIEWER = BUILD / ("goosecraft-client" + EXT)
DEBUG_VIEWER = BUILD / ("goosecraft-client-debug" + EXT)


def environment():
    env = os.environ.copy()
    env["GOOSE_HOME"] = str(ROOT / ".cache/goose-home")
    env["GOOSE_STDLIB"] = str(ROOT / ".cache/upstream/goose/stdlib")
    env["GOOSE_PROGRESS"] = "plain"
    env.setdefault("CMAKE_BUILD_PARALLEL_LEVEL", "2")
    # A headless check should never depend on an attached desktop.
    env.pop("DISPLAY", None)
    env.pop("WAYLAND_DISPLAY", None)
    return env


def run(args, expected=0, cwd=ROOT, extra_env=None, timeout=180):
    if not isinstance(args, str):
        args = list(map(str, args))
    print("+", args if isinstance(args, str) else " ".join(args), flush=True)
    env = environment()
    if extra_env:
        env.update(extra_env)
    p = subprocess.run(args, cwd=cwd, env=env, text=True,
                       encoding="utf-8", capture_output=True, timeout=timeout)
    if p.stdout:
        print(p.stdout, end="")
    if p.stderr:
        print(p.stderr, end="", file=sys.stderr)
    if p.returncode != expected:
        raise RuntimeError(f"exit {p.returncode}, expected {expected}: {args}")
    return p


def build():
    BUILD.mkdir(exist_ok=True)
    run([GOOSE, "check", ROOT / "src/client.goose", "--offline"])
    run([GOOSE, "build", ROOT / "src/client.goose", "--offline", "-o", CLIENT])


def test():
    run([GOOSE, "format", "--check", ROOT / "src", ROOT / "tests/headless.goose", ROOT / "tests/mesh.goose", ROOT / "tests/player.goose", ROOT / "benchmarks"])
    run([GOOSE, "check", ROOT / "tests/headless.goose", "--offline"])
    bad = run([GOOSE, "check", ROOT / "tests/fixtures/type_error.goose", "--offline"], expected=1)
    if "expected a value of type i64" not in bad.stderr:
        raise RuntimeError("Negative probe failed for an unexpected reason")
    for source, label in (("headless", "core"), ("mesh", "mesh"), ("player", "player")):
        for flags in ([], ["--debug"]):
            run([GOOSE, "run", ROOT / f"tests/{source}.goose", "--offline", *flags])
            binary = BUILD / (label + "-tests" + ("-debug" if flags else "") + EXT)
            run([GOOSE, "build", ROOT / f"tests/{source}.goose", "--offline", *flags, "-o", binary])
            result = run([binary])
            if result.stdout.strip() != f"headless {label}: ok":
                raise RuntimeError("Missing Goose assertions result")
    # Test the built executable from a different working directory, including spaces.
    scratch = BUILD / "unrelated working directory"
    scratch.mkdir(exist_ok=True)
    for ticks in (0, 1, 20, 1000, 1000000):
        expected = {"mode": "headless", "ticks": ticks, "solid_blocks": 256}
        native = run([CLIENT, "--headless", "--ticks", str(ticks)], cwd=scratch)
        jit = run([GOOSE, "run", ROOT / "src/client.goose", "--offline",
                   "--", "--headless", "--ticks", str(ticks)], cwd=scratch)
        if json.loads(native.stdout) != expected or native.stdout != jit.stdout:
            raise RuntimeError("Native and TinyCC simulation results disagree")
    if json.loads(run([CLIENT, "--headless"]).stdout)["ticks"] != 20:
        raise RuntimeError("Bad default tick count")
    for args in ([], ["--help"], ["--version"]):
        if "GooseCraft" not in run([CLIENT, *args]).stdout:
            raise RuntimeError("Missing version/help")
    invalid = [
        ["--unknown"], ["--headless", "--ticks"], ["--headless", "extra"],
        ["--headless", "--ticks", "1", "extra"],
        ["--headless", "--ticks", "-1"], ["--headless", "--ticks", "1000001"],
        ["--headless", "--ticks", "abc"], ["--headless", "--ticks", "1.5"],
        ["--headless", "--ticks", "9999999999999999999999999999"],
    ]
    for args in invalid:
        if "invalid arguments" not in run([CLIENT, *args], expected=2).stderr:
            raise RuntimeError("Missing CLI diagnostic")
    if WINDOWS:
        # Real cmd.exe tests, not an emulation of Windows quoting on Linux.
        folder = BUILD / "launcher smoke with spaces"
        folder.mkdir(exist_ok=True)
        launcher = folder / "goosecraft.cmd"
        shutil.copy2(ROOT / "launcher/goosecraft.cmd", launcher)
        target = folder / CLIENT.name
        target.unlink(missing_ok=True)
        command = 'cmd.exe /d /s /c ""' + str(launcher) + '" --headless --ticks 3"'
        run(command, expected=3, cwd=scratch)
        shutil.copy2(CLIENT, target)
        p = run(command, cwd=scratch)
        if json.loads(p.stdout)["ticks"] != 3:
            raise RuntimeError("Launcher arguments were not forwarded")
        run('cmd.exe /d /s /c ""' + str(launcher) + '" --headless --invalid"', expected=2, cwd=scratch)
        if VIEWER.is_file():
            shutil.copy2(VIEWER, folder / VIEWER.name)
            help_result = run('cmd.exe /d /s /c ""' + str(launcher) + '" --help"', cwd=scratch)
            if "graphical scene" not in help_result.stdout:
                raise RuntimeError("Launcher did not select the graphical client")
            run('cmd.exe /d /s /c ""' + str(launcher) + '" --invalid"', expected=2, cwd=scratch)
    print("PASS: compiler probes, Goose core/mesh/player (JIT/native, release/debug), CLI" +
          (", Windows launcher" if WINDOWS else "; Windows launcher not run on Linux"))


def benchmark(evidence):
    evidence.mkdir(parents=True, exist_ok=True)
    binary = BUILD / ("mesh-benchmark" + EXT)
    run([GOOSE, "build", ROOT / "benchmarks/mesh.goose", "--offline", "-o", binary])
    toolchain = run([GOOSE, "toolchain"]).stdout
    result = run([binary, "--iterations", "200"])
    samples = [json.loads(line) for line in result.stdout.splitlines()]
    summaries = {}
    for name in ("empty", "flat", "full", "demo", "terrain", "checker"):
        rows = [row for row in samples if row["scene"] == name]
        if len(rows) != 7 or {row["sample"] for row in rows} != set(range(7)):
            raise RuntimeError("Benchmark is missing samples")
        first = rows[0]
        if any(row["checksum"] != first["checksum"] or row["iterations"] != 200 for row in rows):
            raise RuntimeError("Benchmark geometry changed between samples")
        old_us = statistics.median(row["reference_ns"] / row["iterations"] / 1000 for row in rows)
        new_us = statistics.median(row["greedy_ns"] / row["iterations"] / 1000 for row in rows)
        old_bytes = first["reference_vertices"] * 16 + first["reference_indices"] * 4
        new_bytes = first["greedy_vertices"] * 16 + first["greedy_indices"] * 4
        if not (old_us > 0 and new_us > 0 and 0 <= new_bytes <= old_bytes):
            raise RuntimeError("Invalid benchmark result")
        summaries[name] = {"reference_quads": first["reference_vertices"] // 4,
                           "greedy_quads": first["greedy_vertices"] // 4,
                           "reference_mesh_bytes": old_bytes, "greedy_mesh_bytes": new_bytes,
                           "reference_median_us": old_us, "greedy_median_us": new_us,
                           "cpu_speedup": old_us / new_us}
    if any(summaries[name]["greedy_quads"] != 6 for name in ("flat", "full")):
        raise RuntimeError("Greedy meshing did not merge the uniform surface")
    if summaries["checker"]["reference_quads"] != summaries["checker"]["greedy_quads"]:
        raise RuntimeError("Checkerboard worst case must preserve its isolated faces")
    report = {"platform": platform.platform(), "architecture": platform.machine(),
              "toolchain": toolchain, "lock": json.loads((ROOT / "toolchain.lock.json").read_text()),
              "method": {"samples": 7, "iterations_per_sample": 200, "warmup_builds": 8,
                         "alternating_algorithm_order": True, "clock": "os.clock_ns (monotonic)",
                         "scope": "one-chunk CPU meshing; no FPS or Minecraft comparison",
                         "memory_scope": "logical vertex/index bytes; excludes capacity, scratch, total RSS/VRAM",
                         "greedy_scratch_bytes": 24672},
              "scenes": summaries, "raw_samples": samples}
    (evidence / "mesh-benchmark.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summaries, indent=2))
    print("PASS: native meshing benchmark recorded; timings are observations, not CI performance gates")


def render_build():
    pin = json.loads((ROOT / "toolchain.lock.json").read_text())["graphics"]
    source = ROOT / ".cache/upstream/goose_gfx"
    actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(source), "status", "--porcelain"], text=True).strip()
    submodules = subprocess.check_output(["git", "-C", str(source), "submodule", "status", "--recursive"], text=True)
    if actual != pin["commit"] or dirty or any(not line.startswith(" ") for line in submodules.splitlines()):
        raise RuntimeError("Graphics source differs from its pin; run bootstrap.py --graphics")
    if {line.split()[1]: line.split()[0] for line in submodules.splitlines()} != pin["submodules"]:
        raise RuntimeError("Graphics submodule pins differ")
    BUILD.mkdir(exist_ok=True)
    run([GOOSE, "check", ROOT / "src/viewer.goose", "--offline"])
    run([GOOSE, "build", ROOT / "src/viewer.goose", "--offline", "-o", VIEWER], timeout=900)
    run([VIEWER, "--help"])
    for args in (["--frames", "0"], ["--replay", "--empty"], ["--preview", "--replay"]):
        run([VIEWER, *args], expected=2)
    run([GOOSE, "build", ROOT / "src/viewer.goose", "--offline", "--debug", "-o", DEBUG_VIEWER], timeout=900)


def render_test(evidence):
    if WINDOWS:
        raise RuntimeError("Software Vulkan smoke test currently requires the Linux graphics container")
    evidence.mkdir(parents=True, exist_ok=True)
    icds = list(Path("/usr/share/vulkan/icd.d").glob("lvp_icd*.json"))
    if len(icds) != 1 or not shutil.which("xvfb-run"):
        raise RuntimeError("Install lavapipe and Xvfb, or use the graphics Docker target")
    runtime = BUILD / "xdg-runtime"
    runtime.mkdir(mode=0o700, exist_ok=True)
    env = {"VK_ICD_FILENAMES": str(icds[0]), "SDL_GPU_DRIVER": "vulkan",
           "XDG_RUNTIME_DIR": str(runtime), "GOOSE_GFX_HEADLESS": "0"}
    info = run(["vulkaninfo", "--summary"], extra_env=env)
    if "llvmpipe" not in info.stdout.lower():
        raise RuntimeError("Expected Mesa's software Vulkan device")
    (evidence / "vulkan.txt").write_text(info.stdout + info.stderr)
    no_display = run([VIEWER, "--frames", "1"], expected=3, extra_env={**env, "SDL_VIDEODRIVER": "x11"})
    if "graphics unavailable" not in no_display.stderr:
        raise RuntimeError("Window startup without DISPLAY did not produce the expected diagnostic")
    results = {}
    xvfb = ["xvfb-run", "-a", "-s", "-screen 0 800x600x24"]
    for name, prefix, flags, frames in (
        ("empty", [], ["--offscreen", "--empty"], 3),
        ("offscreen", [], ["--offscreen", "--preview"], 3),
        ("window", xvfb, ["--preview"], 3),
        ("play-window", xvfb, [], 3),
        ("replay-before", [], ["--offscreen", "--replay"], 2),
        ("replay-broken", [], ["--offscreen", "--replay"], 4),
        ("replay-paused", [], ["--offscreen", "--replay"], 63),
        ("replay-offscreen", [], ["--offscreen", "--replay"], 110),
        ("replay-window", xvfb, ["--replay"], 110),
        ("replay-debug", [], ["--offscreen", "--replay"], 110),
    ):
        png = evidence / f"{name}.png"
        png.unlink(missing_ok=True)
        case_env = {**env, "SDL_VIDEODRIVER": "x11" if prefix else "offscreen"}
        binary = DEBUG_VIEWER if name == "replay-debug" else VIEWER
        p = run([*prefix, binary, *flags, "--frames", str(frames), "--screenshot", png], extra_env=case_env)
        data = json.loads(p.stdout)
        if data["driver"] != "vulkan" or data["frames"] != frames or data["misuse_count"] != 0:
            raise RuntimeError("Unexpected renderer result")
        if (data["width"], data["height"]) != (640, 480):
            raise RuntimeError("Unexpected render dimensions")
        if name == "empty":
            if data["colored_pixels"] != 0 or data["indices"] != 0:
                raise RuntimeError("Empty render is not the clear color")
        elif not (5000 < data["colored_pixels"] < 640 * 480 and data["indices"] > 0):
            raise RuntimeError("Scene geometry is missing from GPU readback")
        raw = png.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR" or struct.unpack(">II", raw[16:24]) != (640, 480):
            raise RuntimeError("Invalid screenshot")
        data["png_sha256"] = hashlib.sha256(raw).hexdigest()
        results[name] = data
    if results["offscreen"]["png_sha256"] != results["window"]["png_sha256"]:
        raise RuntimeError("Window and offscreen rendering disagree")
    if not results["play-window"]["interactive"] or results["play-window"]["replay"]:
        raise RuntimeError("Default window did not enter the playable client")
    before, broken = results["replay-before"], results["replay-broken"]
    if before["breaks"] != 0 or broken["breaks"] != 1 or broken["solid_blocks"] != before["solid_blocks"] - 1:
        raise RuntimeError("Injected mouse click did not remove exactly one voxel")
    if before["png_sha256"] == broken["png_sha256"] or before["indices"] == broken["indices"]:
        raise RuntimeError("World edits did not reach GPU geometry and pixels")
    if before["colored_pixels"] - broken["colored_pixels"] < 1000:
        raise RuntimeError("Removed voxel did not leave a visible hole in the scene")
    for name in ("replay-offscreen", "replay-window", "replay-debug"):
        data = results[name]
        expected = {"interactive": True, "replay": True, "breaks": 1, "places": 1,
                    "remeshes": 3, "solid_blocks": 267, "jumps": 1, "respawns": 1,
                    "paused_frames": 14, "focus_losses": 1, "resumes": 3, "ticks": 192}
        if any(data[key] != value for key, value in expected.items()):
            raise RuntimeError(f"Input/physics/edit replay disagrees: {name}: {data}")
        if data["walked"] < 2.0 or data["max_y"] < 1.15:
            raise RuntimeError("Replay did not exercise player movement and jumping")
        if any(abs(data[key] - value) > 0.001 for key, value in
               (("player_x", 10.5), ("player_y", 1.0), ("player_z", 13.5))):
            raise RuntimeError("Respawn or focus-loss key reset failed")
    a, b = results["replay-offscreen"].copy(), results["replay-window"].copy()
    a.pop("mode"); b.pop("mode")
    if a != b:
        raise RuntimeError("Window and offscreen gameplay replay disagree")
    c = results["replay-debug"].copy(); c.pop("mode")
    if a != c:
        raise RuntimeError("Debug and release gameplay replay disagree")
    (evidence / "render-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("PASS: native software Vulkan, X11/Xvfb, default playable window, injected input replay, "
          "movement/jump/edit/remesh/pause/focus/respawn, identical window/offscreen state and PNG")


def package(graphics=False):
    destination = ROOT / "dist" / ("goosecraft-windows-x64" if WINDOWS else "goosecraft-linux-x64")
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    shutil.copy2(CLIENT, destination)
    if graphics:
        shutil.copy2(VIEWER, destination)
    if WINDOWS:
        shutil.copy2(ROOT / "launcher/goosecraft.cmd", destination)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "toolchain.lock.json"):
        shutil.copy2(ROOT / name, destination)
    shutil.copytree(ROOT / "licenses", destination / "licenses")
    shutil.copytree(ROOT / "docs", destination / "docs")
    print("Packaged", destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "test", "benchmark", "package", "render-build", "render-test"])
    parser.add_argument("--graphics", action="store_true", help="include graphical client when packaging")
    parser.add_argument("--evidence", type=Path, default=BUILD / "render-evidence")
    opts = parser.parse_args()
    os.chdir(ROOT)
    if not GOOSE.is_file():
        parser.error("Run python tools/bootstrap.py first")
    if opts.command == "benchmark":
        BUILD.mkdir(exist_ok=True)
        benchmark(opts.evidence.resolve())
        return
    if opts.command in ("render-build", "render-test"):
        render_build()
        if opts.command == "render-test":
            render_test(opts.evidence.resolve())
        return
    build()
    if opts.command == "test":
        test()
    elif opts.command == "package":
        if opts.graphics:
            render_build()
        package(opts.graphics)


if __name__ == "__main__":
    main()
