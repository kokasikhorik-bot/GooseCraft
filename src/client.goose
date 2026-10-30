import std;
import os;
import core.core;

fn usage() {
    print("GooseCraft 0.8.0 (headless harness)");
    print("usage: goosecraft-headless --headless [--ticks N | --inspect-world FILE] | --version | --help");
    print("Graphical client: goosecraft-client.");
    print("Generate: --headless --generate-world SEED FILE [--radius 1..4], default 1; never replaces existing files.");
}

fn invalid_args() {
    write_stderr("invalid arguments: use --help\n");
    exit(2);
}

fn main() {
    let argv = args();
    if argv.len == 1 { usage(); return; }
    if argv.len == 2 && argv[1] == "--help" { usage(); return; }
    if argv.len == 2 && argv[1] == "--version" {
        print("GooseCraft 0.8.0");
        return;
    }
    if argv[1] != "--headless" { invalid_args(); }
    if (argv.len == 5 || argv.len == 7) && argv[2] == "--generate-world" {
        let n, ok = parse_int(argv[3]);
        if !ok || n < 0 || n > 4294967295 || argv[4].len == 0 { invalid_args(); }
        var radius: i64 = 1;
        if argv.len == 7 {
            if argv[5] != "--radius" { invalid_args(); }
            let r, valid = parse_int(argv[6]);
            if !valid || r < 1 || r > 4 { invalid_args(); }
            radius = r;
        }
        if file_exists(argv[4]) || is_dir(argv[4]) {
            write_stderr("world path already exists; original file was not changed\n"); exit(5);
        }
        var map = terrain::generate(n as u32, false, radius);
        if !storage::save(argv[4], map) { write_stderr("world generation save failed\n"); exit(6); }
        print("{\"mode\":\"world-generate\",\"seed\":", n,
              ",\"generator\":1,\"chunks\":", world::count(map), ",\"solid_blocks\":", world::solid_count(map), "}");
        return;
    }
    if argv.len == 4 && argv[2] == "--inspect-world" {
        var map = world::Map {};
        if !storage::load(argv[3], map) { write_stderr("invalid or unreadable world file\n"); exit(5); }
        print("{\"mode\":\"world-inspect\",\"chunks\":", world::count(map),
              ",\"solid_blocks\":", world::solid_count(map), ",\"format\":", storage::version(map), "}");
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
