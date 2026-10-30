import os;
import core from "../src/core";

fn sample(frame: i64) -> profiling::Sample {
    let pump = 10 + frame % 7; let game = 20 + frame % 11;
    let mesh: i64 = if frame % 13 == 0 { 50 } else { 0 };
    let save: i64 = if frame % 23 == 0 { 500 } else { 0 };
    let submit = 30 + frame % 5;
    return profiling::Sample { frame: frame, wall_ns: pump + game + mesh + save + submit,
        pump_ns: pump, game_ns: game, mesh_ns: mesh, save_ns: save, submit_ns: submit,
        rebuilt: if mesh > 0 { 1 } else { 0 }, draw_calls: 5, uploaded_bytes: if mesh > 0 { 88 } else { 0 },
        paused: if frame % 10 == 0 { 1 } else { 0 }, save_calls: if save > 0 { 1 } else { 0 },
    };
}

fn basics() {
    var log = profiling::Log { warmup: 0 };
    assert(profiling::summarize(log, 0) == profiling::Summary {});
    var bad = sample(0); bad.game_ns = -1;
    assert(!profiling::record(log, bad) && log.seen == 0);
    bad = sample(0); bad.wall_ns++;
    assert(!profiling::record(log, bad) && log.seen == 0);
    bad = sample(1);
    assert(!profiling::record(log, bad) && log.seen == 0);
    bad = sample(0); bad.paused = 2;
    assert(!profiling::record(log, bad) && log.seen == 0);
    assert(profiling::record(log, sample(0)));
    let summary = profiling::summarize(log, 0);
    assert(summary.count == 1 && summary.min_ns == sample(0).wall_ns && summary.p99_ns == summary.min_ns);
    let before = log;
    assert(!profiling::record(log, sample(0)) && log == before);
    var values: i64[2] = [10, 20];
    assert(profiling::percentile(values, 50) == 10 && profiling::percentile(values, 95) == 20);
    var warmup = profiling::Log { warmup: 10 };
    for i in 4 { assert(profiling::record(warmup, sample(i))); }
    assert(warmup.seen == 4 && warmup.count == 0);
    assert(profiling::summarize(warmup, 0).count == 0);
}

fn disk(path: u8[:], blocked: u8[:]) {
    var log = profiling::Log { warmup: 3 };
    for i in 1100 { assert(profiling::record(log, sample(i))); }
    assert(log.seen == 1100 && log.count == 1024);
    assert(bytes_of(log.samples).len == 98304);
    assert(profiling::sample(log, 0).frame == 76 && profiling::sample(log, 1023).frame == 1099);
    for metric in 6 {
        let stats = profiling::summarize(log, metric);
        assert(stats.count == 1024 && stats.min_ns <= stats.p50_ns && stats.p50_ns <= stats.p95_ns &&
               stats.p95_ns <= stats.p99_ns && stats.p99_ns <= stats.max_ns);
    }
    assert(profiling::sample(log, 0).frame == 76); // Sorting never reorders raw samples.
    assert(profiling::save(path, log, profiling::Context {}));
    var original: u8[>..] = []; assert(read_file(path, original));
    assert(!profiling::save(path, log, profiling::Context {}));
    var retained: u8[>..] = []; assert(read_file(path, retained) && original == retained);
    assert(!profiling::save(blocked, log, profiling::Context {}));
    var invalid: u8[>..] = [];
    assert(!profiling::encode(log, profiling::Context { driver: "bad\"driver" }, invalid) && invalid.len == 0);
}

fn main() {
    basics();
    let argv = args(); assert(argv.len == 3);
    disk(argv[1], argv[2]);
    print("headless profiling: ok");
}
