import std;
import os;
import core.core;

fn usage() {
    print("GooseCraft 0.15.0 (headless harness)");
    print("usage: goosecraft-headless --headless [--ticks N | --inspect-world FILE] | --version | --help");
    print("Graphical client: goosecraft-client.");
    print("Generate: --headless --generate-world SEED FILE [--radius 1..4], default 1; never replaces existing files.");
    print("Paged storage: --headless --create-pages SEED NEW-DIR | --inspect-pages DIR | --import-world FILE NEW-DIR | --export-pages DIR NEW-FILE.");
    print("Tall GCW v4: --headless --generate-tall SEED NEW-FILE [--radius 0..4] | --inspect-tall FILE | --import-tall OLD-GCW NEW-FILE.");
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
        print("GooseCraft 0.15.0");
        return;
    }
    if argv[1] != "--headless" { invalid_args(); }
    if argv.len == 4 && argv[2] == "--inspect-tall" {
        var map = world::Tall {};
        if !tall_store::load(argv[3], map) { write_stderr("invalid or unreadable tall world\n"); exit(5); }
        print("{\"mode\":\"tall-inspect\",\"format\":4,\"columns\":", world::count(map) / 4,
            ",\"sections\":", world::count(map), ",\"solid_blocks\":", world::solid_count(map),
            ",\"min_y\":-16,\"max_y_exclusive\":48,\"generator\":", map.generator, ",\"seed\":", map.seed, "}"); return;
    }
    if argv.len == 5 && argv[2] == "--import-tall" {
        if file_exists(argv[4]) || is_dir(argv[4]) { write_stderr("new tall path required; existing data retained\n"); exit(5); }
        if !tall_store::import_legacy(argv[3], argv[4]) { write_stderr("tall migration failed; source was not changed\n"); exit(6); }
        print("{\"mode\":\"tall-import\",\"format\":4}"); return;
    }
    if (argv.len == 5 || argv.len == 7) && argv[2] == "--generate-tall" {
        let n, ok = parse_int(argv[3]);
        if !ok || n < 0 || n > 4294967295 || argv[4].len == 0 { invalid_args(); }
        var radius: i64 = 1;
        if argv.len == 7 {
            if argv[5] != "--radius" { invalid_args(); } let r, valid = parse_int(argv[6]);
            if !valid || r < 0 || r > 4 { invalid_args(); } radius = r;
        }
        if file_exists(argv[4]) || is_dir(argv[4]) { write_stderr("new tall path required\n"); exit(5); }
        var map = world::generate_tall(n as u32, radius);
        if !tall_store::save(argv[4], map) { write_stderr("tall save failed\n"); exit(6); }
        print("{\"mode\":\"tall-generate\",\"format\":4,\"generator\":2,\"seed\":", n,
            ",\"columns\":", world::count(map) / 4, ",\"sections\":", world::count(map),
            ",\"solid_blocks\":", world::solid_count(map), "}"); return;
    }
    if argv.len == 5 && (argv[2] == "--create-pages" || argv[2] == "--import-world") {
        var seed: u32 = 12345;
        if argv[2] == "--create-pages" {
            let n, ok = parse_int(argv[3]); if !ok || n < 0 || n > 4294967295 { invalid_args(); } seed = n as u32;
        } else if !file_exists(argv[3]) { write_stderr("source world is not a file\n"); exit(5); }
        if !pages::prepare_new(argv[4]) { write_stderr("new paged path required; existing data retained\n"); exit(5); }
        let handle = pages::lock(argv[4]); if handle == 0 { write_stderr("paged world is locked or unavailable\n"); exit(8); }
        defer pages::unlock(handle);
        let ok = if argv[2] == "--create-pages" { pages::create(argv[4], seed, 4) } else { pages::import_world(argv[3], argv[4]) };
        if !ok { write_stderr("paged world creation failed; no index published\n"); exit(6); }
        print("{\"mode\":\"pages-create\",\"format\":3}"); return;
    }
    if (argv.len == 4 && argv[2] == "--inspect-pages") || (argv.len == 5 && argv[2] == "--export-pages") {
        if !is_dir(argv[3]) { write_stderr("invalid paged world directory\n"); exit(5); }
        let handle = pages::lock(argv[3]); if handle == 0 { write_stderr("paged world is locked or unavailable\n"); exit(8); }
        defer pages::unlock(handle);
        var map = world::Paged {}; if !pages::open(argv[3], map) { write_stderr("invalid paged index\n"); exit(5); }
        if argv[2] == "--export-pages" {
            if file_exists(argv[4]) || is_dir(argv[4]) { write_stderr("new export file required\n"); exit(5); }
            if !pages::export_world(argv[3], argv[4]) { write_stderr("page validation or export failed\n"); exit(6); }
            print("{\"mode\":\"pages-export\",\"format\":", if map.radius <= 1 { 1 } else { 2 }, "}"); return;
        }
        var chunk = world::Chunk {};
        for at in world::slots(map) {
            if world::active(map, at) && !pages::read_page(argv[3], map.index, at, chunk) { write_stderr("invalid or missing page\n"); exit(5); }
        }
        print("{\"mode\":\"pages-inspect\",\"format\":3,\"chunks\":", world::count(map),
              ",\"solid_blocks\":", world::solid_count(map), ",\"generator\":", map.index.generator,
              ",\"seed\":", map.index.seed, ",\"serial\":", map.index.serial, "}"); return;
    }
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
