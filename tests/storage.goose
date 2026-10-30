import os;
import core from "../src/core";

fn repair_checksum(data: u8[:]) {
    let sum = storage::checksum(data);
    for i in 4 { data[12 + i] = (sum >> (i * 8)) as! u8; }
}

fn codec(single: bool) {
    var map = world::region(single, false);
    world::set(map, 15, 2, 10, 2);
    var data: u8[>..] = [];
    assert(storage::encode(map, data));
    assert(data.len == 16 + (if single { 1 } else { 9 }) * 4096);
    var loaded = world::region(false, true);
    assert(storage::decode(data, loaded) && loaded.radius == map.radius);
    for at in 9 { if world::active(map, at) { assert(map.chunks[at] == loaded.chunks[at]); } }
    assert(world::pending(loaded) == (if single { 1 } else { 9 }));
    let before = loaded;
    for length in 16 { assert(!storage::decode(data[..length], loaded) && loaded == before); }
    assert(!storage::decode(data[..data.len - 1], loaded) && loaded == before);
    data.push(0);
    assert(!storage::decode(data, loaded) && loaded == before);
    data.resize(data.len - 1, 0);
    let original = data[100]; data[100] ^= 1;
    assert(!storage::decode(data, loaded) && loaded == before);
    data[100] = original;
    data[8] = 2; repair_checksum(data);
    assert(!storage::decode(data, loaded) && loaded == before);
    data[8] = 1; data[10] = 8; repair_checksum(data);
    assert(!storage::decode(data, loaded) && loaded == before);
    data[10] = if single { 1 } else { 9 }; data[100] = 3; repair_checksum(data);
    assert(!storage::decode(data, loaded) && loaded == before);
}

fn disk(path: u8[:], blocked: u8[:]) {
    var map = world::region(false, false);
    assert(storage::save(path, map));
    world::set(map, -1, 3, -1, 2);
    assert(storage::save(path, map)); // Atomically replace an existing file.
    var loaded = world::region(true, true);
    assert(storage::load(path, loaded));
    assert(world::get(loaded, -1, 3, -1) == 2 && loaded.radius == 1);
    var original: u8[>..] = [];
    assert(read_file(path, original));
    map.chunks[4].blocks[0] = 255;
    assert(!storage::save(path, map));
    var retained: u8[>..] = [];
    assert(read_file(path, retained) && retained == original);
    map.chunks[4].blocks[0] = 1;
    assert(!storage::save(blocked, map));
    let before = loaded;
    assert(write_file(path, "bad world"));
    assert(!storage::load(path, loaded) && loaded == before);
    assert(write_file_atomic(path, original));
    assert(storage::load(path, loaded));
    assert(delete_file(path));
    assert(!storage::load(path, loaded));
    assert(storage::save(path, map)); // Leave an independently inspectable artifact.
}

fn main() {
    let profile_path = storage::default_path();
    let suffix = "/GooseCraft/worlds/default-v1.gcw";
    assert(profile_path.len > suffix.len && profile_path[profile_path.len - suffix.len..] == suffix);
    codec(false); codec(true);
    let argv = args();
    assert(argv.len == 3);
    disk(argv[1], argv[2]);
    print("headless storage: ok");
}
