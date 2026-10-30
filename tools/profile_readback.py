"""Independently validate Goose profiling JSON and recompute every summary."""
import json
import math
from fractions import Fraction

COLUMNS = ["frame", "wall_ns", "pump_ns", "game_ns", "mesh_ns", "save_ns", "submit_ns",
           "rebuilt", "draw_calls", "uploaded_bytes", "paused", "save_calls"]
METRICS = COLUMNS[1:7]


def validate_profile(path, expected_frames=None):
    data = json.loads(path.read_text(encoding="utf-8"))
    if (data["schema"], data["clock"], data["capacity"], data["sample_storage_bytes"], data["columns"]) != (
            1, "os.clock_ns", 1024, 98304, COLUMNS):
        raise ValueError("Unexpected profile schema")
    seen, warmup, count = data["seen"], data["warmup_requested"], data["retained"]
    if any(type(x) is not int or x < 0 for x in (seen, warmup, count)):
        raise ValueError("Invalid profile counters")
    dropped = min(seen, warmup)
    if count != min(1024, seen - dropped) or data["warmup_discarded"] != dropped or data["overwritten"] != seen - dropped - count:
        raise ValueError("Profile warmup/ring accounting disagrees")
    if expected_frames is not None and seen != expected_frames:
        raise ValueError("Missing completed frames in profile")
    if len(data["rows"]) != count:
        raise ValueError("Missing retained samples")
    first = seen - count
    for index, row in enumerate(data["rows"]):
        if len(row) != len(COLUMNS) or any(type(v) is not int or v < 0 for v in row):
            raise ValueError("Invalid profile row")
        if row[0] != first + index or row[1] != sum(row[2:7]) or row[10] not in (0, 1) or row[11] not in (0, 1):
            raise ValueError("Profile ordering/stage durations disagree")
    for metric in METRICS:
        values = sorted(row[COLUMNS.index(metric)] for row in data["rows"])
        def percentile(percent):
            return values[math.ceil(Fraction(percent, 100) * len(values)) - 1] if values else 0
        wanted = {"count": count, "min_ns": min(values, default=0), "p50_ns": percentile(50),
                  "p95_ns": percentile(95), "p99_ns": percentile(99), "max_ns": max(values, default=0),
                  "mean_ns": sum(values) // len(values) if values else 0}
        if data["summary"][metric] != wanted:
            raise ValueError(f"Goose summary differs from independent raw-sample recomputation: {metric}")
    if data["startup_ns"] < data["initial_mesh_ns"] or data["mesh_capacity_bytes"] < data["mesh_bytes"]:
        raise ValueError("Inconsistent startup or mesh memory accounting")
    if data["active_world_block_bytes"] > data["world_block_capacity_bytes"]:
        raise ValueError("Invalid block storage accounting")
    if not data["readback_performed"] and data["exit_readback_ns"] != 0:
        raise ValueError("Unrequested readback was measured")
    if data["driver"] != "headless" and data["loop_session_ns"] < sum(r[1] for r in data["rows"]) + data["collector_ns_total"]:
        raise ValueError("Retained loops and collector time exceed the whole loop session")
    return data
