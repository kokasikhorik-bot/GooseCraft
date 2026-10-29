"""Fetch and build exactly the Goose revision from toolchain.lock.json."""
import argparse
import importlib.metadata
import json
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "toolchain.lock.json").read_text())
SOURCE = ROOT / ".cache/upstream/goose"
BUILD = ROOT / ".cache/toolchain/build"


def run(*args):
    print("+", " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True, timeout=900)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs", type=int, default=2)
    opts = parser.parse_args()
    if opts.jobs < 1:
        parser.error("--jobs must be positive")
    if platform.machine().lower() not in ("x86_64", "amd64"):
        parser.error("stage 1 supports x64 hosts only")
    if importlib.metadata.version("cmake") != LOCK["cmake"]:
        raise SystemExit("Install tools/requirements.txt into the active Python environment")
    pin = LOCK["goose"]
    if not (SOURCE / ".git").exists():
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        run("git", "init", SOURCE)
        run("git", "-C", SOURCE, "remote", "add", "origin", pin["repository"])
    origin = subprocess.check_output(
        ["git", "-C", str(SOURCE), "remote", "get-url", "origin"], text=True
    ).strip()
    if origin != pin["repository"]:
        raise SystemExit("Unexpected Goose origin; use a fresh .cache directory")
    status = subprocess.check_output(
        ["git", "-C", str(SOURCE), "status", "--porcelain"], text=True
    )
    if status.strip():
        raise SystemExit("Goose source is modified; bootstrap will not overwrite it")
    present = subprocess.run(
        ["git", "-C", str(SOURCE), "cat-file", "-e", pin["commit"] + "^{commit}"],
        capture_output=True,
    ).returncode == 0
    if not present:
        run("git", "-C", SOURCE, "fetch", "--depth", "1", "origin", pin["commit"])
    run("git", "-C", SOURCE, "checkout", "--detach", pin["commit"])
    actual = subprocess.check_output(
        ["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual != pin["commit"]:
        raise SystemExit("Goose revision mismatch")
    run(sys.executable, "-m", "cmake", "-S", SOURCE, "-B", BUILD,
        "-DCMAKE_BUILD_TYPE=Release", "-DGOOSE_BUILTIN_LIBS=" + pin["builtin_libs"],
        "-DGOOSE_VERSION=" + pin["commit"])
    run(sys.executable, "-m", "cmake", "--build", BUILD, "--config", "Release",
        "--parallel", opts.jobs)
    exe = BUILD / ("Release/goose.exe" if sys.platform == "win32" else "goose")
    run(exe, "version")
    run(exe, "toolchain")


if __name__ == "__main__":
    main()
