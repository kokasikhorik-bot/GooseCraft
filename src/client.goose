import std;
import os;
import core.core;

fn usage() {
    print("GooseCraft 0.5.0 (headless harness)");
    print("usage: goosecraft-headless --headless [--ticks N | --inspect-world FILE] | --version | --help");
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
        print("GooseCraft 0.5.0");
        return;
    }
    if argv[1] != "--headless" { invalid_args(); }
    if argv.len == 4 && argv[2] == "--inspect-world" {
        var map = world::Map {};
        if !storage::load(argv[3], map) { write_stderr("invalid or unreadable world file\n"); exit(5); }
        print("{\"mode\":\"world-inspect\",\"chunks\":", if map.radius == 0 { 1 } else { 9 },
              ",\"solid_blocks\":", world::solid_count(map), ",\"format\":1}");
        return;
    }
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
