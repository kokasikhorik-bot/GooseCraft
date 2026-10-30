import std;
import os;
import core.core;

fn usage() {
    print("GooseCraft 0.4.0-optimization1 (headless harness)");
    print("usage: goosecraft-headless --headless [--ticks N] | --version | --help");
    print("Graphical client: goosecraft-client.");
}

fn invalid_args() {
    write_stderr("invalid arguments: use --headless [--ticks N], 0 <= N <= 1000000\n");
    exit(2);
}

fn main() {
    let argv = args();
    if argv.len == 1 { usage(); return; }
    if argv.len == 2 && argv[1] == "--help" { usage(); return; }
    if argv.len == 2 && argv[1] == "--version" {
        print("GooseCraft 0.4.0-optimization1");
        return;
    }
    if argv[1] != "--headless" { invalid_args(); }
    var ticks: i64 = 20;
    if argv.len != 2 {
        if argv.len != 4 { invalid_args(); }
        if argv[2] != "--ticks" { invalid_args(); }
        let n, ok = parse_int(argv[3]);
        if !ok || n < 0 || n > 1000000 { invalid_args(); }
        ticks = n;
    }
    var chunk = world::flat_fixture();
    var state = simulation::State {};
    for i in ticks { simulation::tick(state); }
    print("{\"mode\":\"headless\",\"ticks\":", state.ticks,
          ",\"solid_blocks\":", world::solid_count(chunk), "}");
}
