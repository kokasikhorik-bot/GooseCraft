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
import zlib
import traceback
import xml.etree.ElementTree as ET
from png_readback import compare_boundary_pixels

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
        detail = (p.stderr or p.stdout)[-4000:]
        raise RuntimeError(f"exit {p.returncode}, expected {expected}: {args}\n{detail}")
    return p


def native_build(source, binary, flags=(), timeout=180):
    run([GOOSE, "build", source, "--offline", *flags, "-o", binary], timeout=timeout)
    if WINDOWS:
        # Goose embeds UTF-8 in the compiler's own manifest, but its native
        # build command doesn't propagate that setting to generated programs.
        # Activate it before the CRT constructs argv, not in game main().
        manifest_tool = shutil.which("mt.exe")
        if not manifest_tool:
            sdk = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)")) / "Windows Kits/10/bin"
            candidates = list(sdk.glob("*/x64/mt.exe"))
            candidates.sort(key=lambda p: tuple(int(x) for x in p.parent.parent.name.split(".")))
            if candidates: manifest_tool = candidates[-1]
        if not manifest_tool:
            raise RuntimeError("Windows SDK mt.exe is required to embed the UTF-8 application manifest")
        manifest = ROOT / "resources/windows/GooseCraft.manifest"
        run([manifest_tool, "-nologo", "-manifest", manifest, f"-outputresource:{binary};#1"])
        extracted = Path(str(binary) + ".manifest")
        run([manifest_tool, "-nologo", f"-inputresource:{binary};#1", "-out:" + str(extracted)])
        nodes = ET.parse(extracted).findall(".//{http://schemas.microsoft.com/SMI/2019/WindowsSettings}activeCodePage")
        if len(nodes) != 1 or nodes[0].text.strip() != "UTF-8":
            raise RuntimeError("Native PE does not contain the required UTF-8 activeCodePage")


def build():
    BUILD.mkdir(exist_ok=True)
    run([GOOSE, "check", ROOT / "src/client.goose", "--offline"])
    native_build(ROOT / "src/client.goose", CLIENT)


def test():
    sources = ("headless", "mesh", "player", "region", "storage", "visibility")
    run([GOOSE, "format", "--check", ROOT / "src", *(ROOT / f"tests/{s}.goose" for s in sources),
         ROOT / "tests/support", ROOT / "benchmarks"])
    run([GOOSE, "check", ROOT / "tests/headless.goose", "--offline"])
    bad = run([GOOSE, "check", ROOT / "tests/fixtures/type_error.goose", "--offline"], expected=1)
    if "expected a value of type i64" not in bad.stderr:
        raise RuntimeError("Negative probe failed for an unexpected reason")
    save_folder = BUILD / "storage smoke with spaces" / "миры"
    save_folder.mkdir(parents=True, exist_ok=True)
    blocked = save_folder / "blocked"
    blocked.write_bytes(b"retain this file")
    save_path = save_folder / "nested" / "world.gcw"
    for source in sources:
        label = "core" if source == "headless" else source
        for flags in ([], ["--debug"]):
            extra = [save_path, blocked / "world.gcw"] if source == "storage" else []
            run([GOOSE, "run", ROOT / f"tests/{source}.goose", "--offline", *flags,
                 *(["--", *extra] if extra else [])])
            jit_save = save_path.read_bytes() if extra else None
            binary = BUILD / (label + "-tests" + ("-debug" if flags else "") + EXT)
            native_build(ROOT / f"tests/{source}.goose", binary, flags)
            result = run([binary, *extra])
            if result.stdout.strip() != f"headless {label}: ok":
                raise RuntimeError("Missing Goose assertions result")
            if extra:
                data = save_path.read_bytes()
                if data != jit_save or data[:12] != b"GOOSEWLD\x01\x01\x09\x00" or len(data) != 36880:
                    raise RuntimeError("Native/JIT save format differs")
                if struct.unpack("<I", data[12:16])[0] != zlib.adler32(data[:12] + data[16:]):
                    raise RuntimeError("Save checksum disagrees with independent zlib")
                if sum(value != 0 for value in data[16:]) != 2333 or max(data[16:]) != 2:
                    raise RuntimeError("Save lost blocks or contains unsupported IDs")
                if blocked.read_bytes() != b"retain this file":
                    raise RuntimeError("Failed save modified an unrelated file")
    inspected = json.loads(run([CLIENT, "--headless", "--inspect-world", save_path]).stdout)
    if inspected != {"mode": "world-inspect", "chunks": 9, "solid_blocks": 2333, "format": 1}:
        raise RuntimeError("Native saved-world inspection failed")
    invalid_world = save_folder / "corrupt.gcw"
    invalid_world.write_bytes(b"corrupt world")
    run([CLIENT, "--headless", "--inspect-world", invalid_world], expected=5)
    if invalid_world.read_bytes() != b"corrupt world":
        raise RuntimeError("Inspection overwrote corrupt input")
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
    print("PASS: compiler probes, core/mesh/player/region/storage/visibility (JIT/native, release/debug), "
          "independent save checksum and world inspection, CLI" +
          (", Windows launcher" if WINDOWS else "; Windows launcher not run on Linux"))


def benchmark(evidence):
    evidence.mkdir(parents=True, exist_ok=True)
    binary = BUILD / ("mesh-benchmark" + EXT)
    native_build(ROOT / "benchmarks/mesh.goose", binary)
    toolchain = run([GOOSE, "toolchain"]).stdout
    iterations = 1000
    result = run([binary, "--iterations", str(iterations)])
    samples = [json.loads(line) for line in result.stdout.splitlines()]
    summaries = {}
    for name in ("empty", "flat", "full", "demo", "terrain", "checker"):
        rows = [row for row in samples if row["scene"] == name]
        if len(rows) != 7 or {row["sample"] for row in rows} != set(range(7)):
            raise RuntimeError("Benchmark is missing samples")
        first = rows[0]
        if any(row["checksum"] != first["checksum"] or row["iterations"] != iterations for row in rows):
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
              "sources": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                          for name in ("src/core/mesh.goose", "src/core/world.goose", "benchmarks/mesh.goose")},
              "method": {"samples": 7, "iterations_per_sample": iterations, "warmup_builds": 8,
                         "build": "native release; pinned Goose uses -O2 or /O2",
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
    native_build(ROOT / "src/viewer.goose", VIEWER, timeout=900)
    run([VIEWER, "--help"])
    for args in (["--frames", "0"], ["--replay", "--empty"], ["--preview", "--replay"],
                 ["--seam-replay", "--single-chunk"], ["--world"], ["--world", "x", "--no-save"], ["--view-away"]):
        run([VIEWER, *args], expected=2)
    corrupt = BUILD / "invalid load.gcw"
    corrupt.write_bytes(b"corrupt world")
    run([VIEWER, "--world", corrupt, "--frames", "1"], expected=5)
    if corrupt.read_bytes() != b"corrupt world":
        raise RuntimeError("Graphical startup overwrote corrupt input before opening the GPU")
    native_build(ROOT / "src/viewer.goose", DEBUG_VIEWER, ["--debug"], timeout=900)


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
    no_display = run([VIEWER, "--no-save", "--frames", "1"], expected=3, extra_env={**env, "SDL_VIDEODRIVER": "x11"})
    if "graphics unavailable" not in no_display.stderr:
        raise RuntimeError("Window startup without DISPLAY did not produce the expected diagnostic")
    results = {}
    xvfb = ["xvfb-run", "-a", "-s", "-screen 0 800x600x24"]
    legacy_cases = (
        ("empty", [], ["--offscreen", "--empty"], 3),
        ("offscreen", [], ["--offscreen", "--preview"], 3),
        ("window", xvfb, ["--preview"], 3),
        ("play-window", xvfb, [], 60),
        ("replay-before", [], ["--offscreen", "--replay"], 2),
        ("replay-broken", [], ["--offscreen", "--replay"], 4),
        ("replay-paused", [], ["--offscreen", "--replay"], 63),
        ("replay-offscreen", [], ["--offscreen", "--replay"], 110),
        ("replay-window", xvfb, ["--replay"], 110),
        ("replay-debug", [], ["--offscreen", "--replay"], 110),
        ("reference-preview", [], ["--offscreen", "--preview", "--reference-renderer"], 3),
        ("reference-idle", xvfb, ["--reference-renderer"], 60),
        ("reference-paused", [], ["--offscreen", "--replay", "--reference-renderer"], 63),
        ("reference-replay", [], ["--offscreen", "--replay", "--reference-renderer"], 110),
    )
    cases = [(name, prefix, ["--single-chunk", "--no-save", *flags], frames)
             for name, prefix, flags, frames in legacy_cases]
    saves = BUILD / "persistence smoke with spaces" / "миры"
    if saves.exists(): shutil.rmtree(saves)
    saves.mkdir(parents=True)
    single_save = saves / "single" / "world.gcw"
    multi_save = saves / "region" / "world.gcw"
    profile_root = saves / "profile"
    cases += [
        ("multi-preview", [], ["--offscreen", "--preview", "--no-save"], 3),
        ("multi-window", xvfb, ["--preview", "--no-save"], 3),
        ("multi-replay", [], ["--offscreen", "--replay", "--no-save"], 110),
        ("multi-replay-window", xvfb, ["--replay", "--no-save"], 110),
        ("multi-reference", [], ["--offscreen", "--replay", "--reference-renderer", "--no-save"], 110),
        ("multi-away", [], ["--offscreen", "--preview", "--view-away", "--no-save"], 3),
        ("multi-away-reference", [], ["--offscreen", "--preview", "--view-away", "--reference-renderer", "--no-save"], 3),
        ("seam-replay", [], ["--offscreen", "--seam-replay", "--no-save"], 110),
        ("seam-window", xvfb, ["--seam-replay", "--no-save"], 110),
        ("seam-debug", [], ["--offscreen", "--seam-replay", "--no-save"], 110),
        ("single-save", [], ["--offscreen", "--replay", "--single-chunk", "--world", single_save], 110),
        ("single-load", [], ["--offscreen", "--single-chunk", "--world", single_save], 3),
        ("region-save", [], ["--offscreen", "--seam-replay", "--world", multi_save], 110),
        ("region-load", [], ["--offscreen", "--world", multi_save], 3),
        ("profile-save", xvfb, [], 2),
        ("profile-load", xvfb, [], 2),
    ]
    for name, prefix, flags, frames in cases:
        png = evidence / f"{name}.png"
        png.unlink(missing_ok=True)
        case_env = {**env, "SDL_VIDEODRIVER": "x11" if prefix else "offscreen"}
        if name == "single-load":
            persisted_single = single_save.read_bytes()
        if name == "region-load":
            persisted_region = multi_save.read_bytes()
        binary = DEBUG_VIEWER if name in ("replay-debug", "seam-debug") else VIEWER
        if name.startswith("profile-"):
            case_env["LOCALAPPDATA"] = str(profile_root)
        p = run([*prefix, binary, *flags, "--frames", str(frames), "--screenshot", png], extra_env=case_env)
        data = json.loads(p.stdout)
        if data["driver"] != "vulkan" or data["frames"] != frames or data["misuse_count"] != 0:
            raise RuntimeError("Unexpected renderer result")
        if (data["width"], data["height"]) != (640, 480):
            raise RuntimeError("Unexpected render dimensions")
        if name == "empty" or name.startswith("multi-away"):
            if data["colored_pixels"] != 0 or (name == "empty" and data["indices"] != 0):
                raise RuntimeError("Empty render is not the clear color")
        elif not (5000 < data["colored_pixels"] < 640 * 480 and data["indices"] > 0):
            raise RuntimeError("Scene geometry is missing from GPU readback")
        raw = png.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR" or struct.unpack(">II", raw[16:24]) != (640, 480):
            raise RuntimeError("Invalid screenshot")
        data["png_sha256"] = hashlib.sha256(raw).hexdigest()
        results[name] = data
    if single_save.read_bytes() != persisted_single or multi_save.read_bytes() != persisted_region:
        raise RuntimeError("Loading a save rewrote its bytes without edits")
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
    # GPU counters depend on intermediate target changes and native window
    # events. Compare rendered output and gameplay; check caching separately.
    diagnostic = ("mode", "hud_uploads", "hud_uploaded_bytes", "outline_uploads")
    for key in diagnostic:
        a.pop(key); b.pop(key)
    if a != b:
        raise RuntimeError("Window and offscreen gameplay replay disagree")
    c = results["replay-debug"].copy()
    for key in diagnostic: c.pop(key)
    if a != c:
        raise RuntimeError("Debug and release gameplay replay disagree")
    comparisons = {}
    for optimized, reference in (("offscreen", "reference-preview"), ("play-window", "reference-idle"),
                                 ("replay-paused", "reference-paused"), ("replay-offscreen", "reference-replay")):
        comparisons[optimized] = compare_boundary_pixels(evidence / f"{optimized}.png", evidence / f"{reference}.png")
    keys = ("interactive", "replay", "ticks", "breaks", "places", "solid_blocks", "jumps", "respawns",
            "paused_frames", "focus_losses", "resumes", "walked", "max_y", "player_x", "player_y", "player_z")
    if any(results["replay-offscreen"][key] != results["reference-replay"][key] for key in keys):
        raise RuntimeError("Optimization changed gameplay state")
    idle = results["play-window"]
    if idle["hud_uploads"] != 1 or idle["outline_uploads"] != 1:
        raise RuntimeError("Stationary overlays were rebuilt without a content change")
    if results["reference-idle"]["hud_uploads"] != 60:
        raise RuntimeError("Reference did not exercise the original per-frame HUD upload")
    optimized, reference = results["replay-offscreen"], results["reference-replay"]
    if optimized["mesh_allocations"] >= reference["mesh_allocations"] or optimized["hud_uploads"] >= 30:
        raise RuntimeError("Replay did not reuse GPU buffers and overlay geometry")
    if optimized["mesh_uploaded_bytes"] * 10 >= reference["mesh_uploaded_bytes"]:
        raise RuntimeError("Greedy meshing did not reduce world upload traffic")
    for name, remeshes, rebuilds in (("multi-replay", 11, [1,1,1,1,3,1,1,1,1]),
                                    ("seam-replay", 13, [1,1,1,1,3,3,1,1,1])):
        data = results[name]
        if (data["chunks"], data["solid_blocks"], data["remeshes"], data["dirty_remaining"]) != (9, 2332, remeshes, 0):
            raise RuntimeError(f"Multi-chunk world/dirty schedule disagrees: {name}: {data}")
        if data["chunk_rebuilds"] != rebuilds or data["revision"] != 2:
            raise RuntimeError("An unchanged chunk was rebuilt or a seam neighbor was omitted")
    if results["seam-replay"]["max_x"] <= 16.1 or results["seam-replay"]["breaks"] != 1 or results["seam-replay"]["places"] != 1:
        raise RuntimeError("Seam replay failed to cross and edit a chunk boundary")
    for a_name, b_name in (("multi-preview", "multi-window"), ("multi-replay", "multi-replay-window"),
                           ("seam-replay", "seam-window"), ("seam-replay", "seam-debug"),
                           ("multi-away", "multi-away-reference")):
        if results[a_name]["png_sha256"] != results[b_name]["png_sha256"]:
            raise RuntimeError(f"Multi-chunk PNG differs: {a_name} / {b_name}")
    if any(results["multi-replay"][key] != results["multi-reference"][key] for key in keys):
        raise RuntimeError("Multi-chunk reference gameplay differs")
    comparisons["multi-replay"] = compare_boundary_pixels(evidence / "multi-replay.png", evidence / "multi-reference.png")
    if results["multi-away"]["drawn_chunks"] != 0 or results["multi-away"]["culled_chunks"] != 9:
        raise RuntimeError("Frustum culling did not reject chunks behind the camera")
    if results["multi-away-reference"]["drawn_chunks"] != 9:
        raise RuntimeError("Unculled reference did not submit all nine chunks")
    if results["multi-replay"]["culled_chunks"] < 1 or results["multi-reference"]["drawn_chunks"] != 9:
        raise RuntimeError("Playable camera did not exercise culling")
    for name, expected_chunks, expected_size, expected_count in (
        ("single", 1, 4112, 267), ("region", 9, 36880, 2332), ("profile", 9, 36880, 2332)):
        path = {"single": single_save, "region": multi_save,
                "profile": profile_root / "GooseCraft/worlds/default-v1.gcw"}[name]
        data = path.read_bytes()
        if len(data) != expected_size or struct.unpack("<I", data[12:16])[0] != zlib.adler32(data[:12] + data[16:]):
            raise RuntimeError("Native world bytes fail independent checksum validation")
        checked = json.loads(run([CLIENT, "--headless", "--inspect-world", path]).stdout)
        if (checked["chunks"], checked["solid_blocks"]) != (expected_chunks, expected_count):
            raise RuntimeError("Reopened graphical save lost chunks/blocks")
        first, second = results[name + "-save"], results[name + "-load"]
        if first["loaded"] or first["save_writes"] != 1 or not second["loaded"] or second["save_writes"] != 0:
            raise RuntimeError("Manual/default save and reopen behavior disagrees")
    if single_save.read_bytes()[16 + 10 + 16 * (9 + 16 * 2)] != 0 or single_save.read_bytes()[16 + 10 + 16 * (10 + 16 * 3)] != 2:
        raise RuntimeError("Saved voxel edits were not preserved")
    blocked = saves / "blocked"
    blocked.write_bytes(b"retain")
    failed = run([VIEWER, "--offscreen", "--frames", "1", "--world", blocked / "world.gcw"],
                 expected=6, extra_env={**env, "SDL_VIDEODRIVER": "offscreen"})
    if b"retain" != blocked.read_bytes() or "world save failed" not in failed.stderr:
        raise RuntimeError("Save error damaged an unrelated file or missed the diagnostic")
    (evidence / "save-results.json").write_text(json.dumps({"single_bytes": len(persisted_single),
        "region_bytes": len(persisted_region), "reopen_preserved_bytes": True,
        "independent_adler32": True, "default_profile_saved": True,
        "failed_save_exit": 6, "blocked_file_preserved": True}, indent=2) + "\n")
    (evidence / "pixel-comparisons.json").write_text(json.dumps(comparisons, indent=2) + "\n")
    (evidence / "render-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"PASS: {len(results)} Vulkan/Xvfb scenarios; single/multi-chunk and seam replay, dirty neighbors, "
          "frustum culling, release/debug/reference, manual/exit saves and reopen, error preservation, cached overlays")


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
    revision = os.environ.get("GITHUB_SHA")
    if not revision:
        git = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True)
        revision = git.stdout.strip() if git.returncode == 0 else None
    status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, text=True, capture_output=True)
    ci_url = None
    if os.environ.get("GITHUB_REPOSITORY") and os.environ.get("GITHUB_RUN_ID"):
        ci_url = f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    (destination / "BUILD-INFO.json").write_text(json.dumps({
        "client_version": run([CLIENT, "--version"]).stdout.strip(),
        "source_commit": revision, "source_dirty": bool(status.stdout) if status.returncode == 0 else None,
        "ci_url": ci_url,
        "target": "windows-x64" if WINDOWS else "linux-x64", "graphics": graphics,
        "world_format": 1,
    }, indent=2) + "\n")
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
        if opts.command == "render-test":
            build() # Native saved-world validator used by the graphics integration tests.
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
    # Windows redirected stdout can default to cp1252. Test paths are UTF-8,
    # including Cyrillic; logging must not fail before the native I/O test.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    try:
        main()
    except Exception:
        if os.environ.get("GITHUB_ACTIONS") == "true":
            detail = traceback.format_exc(limit=12)
            detail = detail.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print("::error title=GooseCraft validation failure::" + detail, file=sys.stderr, flush=True)
        raise
