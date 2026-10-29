"""Build/test entry point, identical on Linux and Windows x64."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WINDOWS = sys.platform == "win32"
EXT = ".exe" if WINDOWS else ""
GOOSE = ROOT / ".cache/toolchain/build" / ("Release/goose.exe" if WINDOWS else "goose")
BUILD = ROOT / "build"
CLIENT = BUILD / ("goosecraft-client" + EXT)


def environment():
    env = os.environ.copy()
    env["GOOSE_HOME"] = str(ROOT / ".cache/goose-home")
    env["GOOSE_STDLIB"] = str(ROOT / ".cache/upstream/goose/stdlib")
    env["GOOSE_PROGRESS"] = "plain"
    # A headless check should never depend on an attached desktop.
    env.pop("DISPLAY", None)
    env.pop("WAYLAND_DISPLAY", None)
    return env


def run(args, expected=0, cwd=ROOT):
    if not isinstance(args, str):
        args = list(map(str, args))
    print("+", args if isinstance(args, str) else " ".join(args), flush=True)
    p = subprocess.run(args, cwd=cwd, env=environment(), text=True,
                       encoding="utf-8", capture_output=True, timeout=180)
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
    run([GOOSE, "format", "--check", ROOT / "src", ROOT / "tests/headless.goose"])
    run([GOOSE, "check", ROOT / "tests/headless.goose", "--offline"])
    bad = run([GOOSE, "check", ROOT / "tests/fixtures/type_error.goose", "--offline"], expected=1)
    if "expected a value of type i64" not in bad.stderr:
        raise RuntimeError("Negative probe failed for an unexpected reason")
    for flags in ([], ["--debug"]):
        run([GOOSE, "run", ROOT / "tests/headless.goose", "--offline", *flags])
        binary = BUILD / ("core-tests" + ("-debug" if flags else "") + EXT)
        run([GOOSE, "build", ROOT / "tests/headless.goose", "--offline", *flags, "-o", binary])
        result = run([binary])
        if result.stdout.strip() != "headless core: ok":
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
        run('cmd.exe /d /s /c ""' + str(launcher) + '" --invalid"', expected=2, cwd=scratch)
    print("PASS: compiler probes, Goose core (JIT/native, release/debug), CLI" +
          (", Windows launcher" if WINDOWS else "; Windows launcher not run on Linux"))


def package():
    destination = ROOT / "dist" / ("goosecraft-windows-x64" if WINDOWS else "goosecraft-linux-x64")
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    shutil.copy2(CLIENT, destination)
    if WINDOWS:
        shutil.copy2(ROOT / "launcher/goosecraft.cmd", destination)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "toolchain.lock.json"):
        shutil.copy2(ROOT / name, destination)
    shutil.copytree(ROOT / "licenses", destination / "licenses")
    print("Packaged", destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build", "test", "package"])
    opts = parser.parse_args()
    os.chdir(ROOT)
    if not GOOSE.is_file():
        parser.error("Run python tools/bootstrap.py first")
    build()
    if opts.command == "test":
        test()
    elif opts.command == "package":
        package()


if __name__ == "__main__":
    main()
