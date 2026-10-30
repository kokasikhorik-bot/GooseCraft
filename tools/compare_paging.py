"""Reproduce the 0.11.0 -> 0.11.1 finite file-backed paging comparison.

Run in the pinned graphics container, after project.py render-test. This is a
software-GPU diagnostic, not an FPS benchmark. Neither client is rebuilt here.
"""
import argparse
import hashlib
import json
from pathlib import Path
import statistics

import project
from png_readback import rgba
from profile_readback import validate_profile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=3, choices=range(1, 6))
    args = parser.parse_args()
    baseline_record = json.loads((project.ROOT / "docs/validation/prefetch/package-results.json").read_text())
    assert digest(args.baseline) == baseline_record["binaries"]["goosecraft-client"], "Baseline is not the archived 0.11.0 binary"
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    saves = project.BUILD / "paging comparison"
    saves.mkdir(parents=True, exist_ok=False)
    origin = saves / "origin.gcw"
    project.run([project.CLIENT, "--headless", "--generate-world", "12345", origin, "--radius", "4"])
    binaries = {"baseline": args.baseline.resolve(), "current": project.VIEWER}
    keys = ("ticks", "breaks", "places", "solid_blocks", "jumps", "respawns", "walked", "max_y", "max_x",
            "player_x", "player_y", "player_z", "revision", "save_writes", "chunk_rebuilds",
            "cpu_peak_chunks", "cpu_evictions", "page_writes", "page_loads", "chunk_generations")
    results = []
    for delay in (0, 2):
        for pair in range(args.pairs):
            sides = {}
            order = ("baseline", "current") if pair % 2 == 0 else ("current", "baseline")
            for side in order:
                label = f"delay-{delay}-pair-{pair}-{side}"
                root = saves / label
                project.run([project.CLIENT, "--headless", "--import-world", origin, root])
                profile, png = evidence / (label + ".json"), evidence / (label + ".png")
                output = project.run(["xvfb-run", "-a", "-s", "-screen 0 800x600x24", binaries[side],
                    "--paged-world", root, "--paging-replay", "--frames", "680", "--page-delay-ms", delay,
                    "--profile", profile, "--profile-warmup", "0", "--screenshot", png],
                    extra_env={"SDL_VIDEODRIVER": "x11", "LIBGL_ALWAYS_SOFTWARE": "1"})
                data = json.loads(output.stdout)
                trace = validate_profile(profile, 680)
                assert data["misuse_count"] == 0 and data["prefetch_completed"] == data["prefetch_submitted"]
                assert data["main_page_reads"] == data["main_disk_page_reads"]
                assert data["diagnostic_page_delay_ms"] == delay
                assert trace["client_version"] == ("0.11.0" if side == "baseline" else "0.11.1")
                exported = saves / (label + ".gcw")
                project.run([project.CLIENT, "--headless", "--export-pages", root, exported])
                row = next(row for row in trace["rows"] if row[0] == 620)
                sides[side] = {"stdout": data, "profile": profile.name, "png": png.name,
                    "export_sha256": digest(exported), "main_preparation_ns": data["main_page_read_ns"],
                    "respawn_wall_ns": row[1], "respawn_game_ns": row[3], "summary": trace["summary"]}
            old, new = sides["baseline"], sides["current"]
            assert all(old["stdout"][key] == new["stdout"][key] for key in keys)
            assert old["export_sha256"] == new["export_sha256"]
            before, after = rgba(evidence / old["png"]), rgba(evidence / new["png"])
            changed = [i // 4 for i in range(0, len(before), 4) if before[i:i + 4] != after[i:i + 4]]
            # The only permitted pixel changes across releases are the version title.
            assert all(12 <= at % 640 < 250 and 10 <= at // 640 < 26 for at in changed)
            results.append({"delay_ms": delay, "pair": pair, "order": order,
                "equal_gameplay": True, "equal_export": True, "pixels_equal_outside_version_title": True,
                "version_title_changed_pixels": len(changed), "runs": sides})
    medians = {}
    for delay in (0, 2):
        medians[str(delay)] = {side: {key: statistics.median(
            result["runs"][side][key] for result in results if result["delay_ms"] == delay)
            for key in ("main_preparation_ns", "respawn_wall_ns", "respawn_game_ns")}
            for side in binaries}
    value = {"scope": "Alternating paired Linux lavapipe/X11 runs, 680 frames; delay=2 is injected latency, not hardware",
        "baseline_source": "437bed6259aff94d534bd53eaf7f4d662b1a7c9e",
        "binary_sha256": {name: digest(path) for name, path in binaries.items()},
        "pairs_per_delay": args.pairs, "medians_ns": medians, "results": results}
    (evidence / "comparison.json").write_text(json.dumps(value, indent=2) + "\n")
    print(json.dumps(medians, indent=2))


if __name__ == "__main__":
    main()
