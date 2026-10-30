// GooseCraft's own bounded world format, unrelated to Minecraft save formats.
// Header (16 bytes): GOOSEWLD, version=1, radius, chunk count, zero, Adler32 LE.
// Payload: active chunks in slot order, each 4096 raw IDs (0/1/2).
import os;
import .world;
namespace storage;

fn checksum(data: const u8[:]) -> u32 {
    var a: i64 = 1;
    var b: i64 = 0;
    for i in data.len {
        if i >= 12 && i < 16 { continue; }
        a = (a + data[i]) % 65521;
        b = (b + a) % 65521;
    }
    return ((b as u32) << 16) | (a as u32);
}

fn encode(map: world::Map&, output: u8[>..]&) -> bool {
    assert(output.len == 0);
    if map.radius != 0 && map.radius != 1 { return false; }
    for at in 9 {
        if world::active(map, at) {
            for value in map.chunks[at].blocks { if value > 2 { return false; } }
        }
    }
    output.append("GOOSEWLD");
    output.append([1, map.radius as u8, if map.radius == 0 { 1 } else { 9 }, 0, 0, 0, 0, 0]);
    for at in 9 { if world::active(map, at) { output.append(map.chunks[at].blocks); } }
    let sum = checksum(output);
    for i in 4 { output[12 + i] = (sum >> (i * 8)) as! u8; }
    return true;
}

fn decode(data: const u8[:], map: world::Map&) -> bool {
    if data.len < 16 || data[..8] != "GOOSEWLD" || data[8] != 1 || data[9] > 1 || data[11] != 0 {
        return false;
    }
    let count: i64 = if data[9] == 0 { 1 } else { 9 };
    if data[10] != count || data.len != 16 + count * 4096 { return false; }
    var expected: u32 = 0;
    for i in 4 { expected |= (data[12 + i] as u32) << (i * 8); }
    if expected != checksum(data) { return false; }
    for i in 16..data.len { if data[i] > 2 { return false; } }
    // Validate completely before assigning: errors preserve live world/dirty state.
    var candidate = world::Map { radius: data[9] };
    var cursor: i64 = 16;
    for at in 9 {
        if world::active(candidate, at) {
            for i in 4096 { candidate.chunks[at].blocks[i] = data[cursor + i]; }
            cursor += 4096;
        }
    }
    world::mark_all(candidate);
    map = candidate;
    return true;
}

fn parent_directories(path: const u8[:]) -> bool {
    for i in 1..path.len {
        if path[i] != '/' && path[i] != '\\' { continue; }
        if i == 2 && path[1] == ':' { continue; } // Windows drive root.
        let directory = path[..i];
        if !is_dir(directory) && !make_dir(directory) { return false; }
    }
    return true;
}

fn save(path: const u8[:], map: world::Map&) -> bool {
    var data: u8[>..] = [];
    if !encode(map, data) || !parent_directories(path) { return false; }
    return write_file_atomic(path, data);
}

fn load(path: const u8[:], map: world::Map&) -> bool {
    var data: u8[>..] = [];
    if !read_file(path, data) { return false; }
    return decode(data, map);
}

fn default_path() -> u8[>..] {
    var base: u8[>..] = [];
    if !env("LOCALAPPDATA", base) || base.len == 0 {
        base.clear();
        if !env("XDG_DATA_HOME", base) || base.len == 0 {
            base.clear();
            if env("HOME", base) && base.len > 0 { base.append("/.local/share"); }
            else { base.append(resource_dir()); base.append("GooseCraftData"); }
        }
    }
    base.append("/GooseCraft/worlds/default-v1.gcw");
    return base;
}
