// Explicit GCW v4. No automatic conversion or writes to legacy source files.
import os;
import .tall_world;
import .storage;
import .fileio;
namespace tall_store;

let MAX_BYTES: i64 = 48 + 324 * 4096;
fn u32_at(data: const u8[:], at: i64) -> u32 {
    var n: u32 = 0; for i in 4 { n |= (data[at + i] as u32) << (8 * i); } return n;
}
fn put(data: u8[:], at: i64, value: u32) { for i in 4 { data[at + i] = (value >> (8 * i)) as! u8; } }
fn encode(map: world::Tall&, output: u8[>..]&) -> bool {
    assert(output.len == 0);
    if !world::valid(map) { return false; }
    for at in world::slots(map) {
        if world::active(map, at) { for value in map.chunks[at].blocks { if value > 2 { return false; } } }
    }
    output.resize(48, 0); for i in 8 { output[i] = "GOOSEWLD"[i]; }
    output[8] = 4; output[9] = map.radius as u8; output[10] = 4;
    put(output, 16, world::count(map) as u32); put(output, 20, 4294967280); put(output, 24, 48);
    put(output, 28, map.generator as u32); put(output, 32, map.seed);
    for at in world::slots(map) { if world::active(map, at) { output.append(map.chunks[at].blocks); } }
    put(output, 12, storage::checksum(output)); return true;
}
fn decode(data: const u8[:], map: world::Tall&) -> bool {
    if data.len < 48 || data[..8] != "GOOSEWLD" || data[8] != 4 || data[9] > 4 || data[10] != 4 || data[11] != 0 ||
       u32_at(data, 20) != 4294967280 || u32_at(data, 24) != 48 ||
       (u32_at(data, 28) != 2 && (u32_at(data, 28) != 0 || u32_at(data, 32) != 0)) { return false; }
    for i in 36..48 { if data[i] != 0 { return false; } }
    let count = 4 * (if data[9] == 0 { 1 } else { world::pool_count(data[9]) });
    if u32_at(data, 16) != count || data.len != 48 + count * 4096 || u32_at(data, 12) != storage::checksum(data) { return false; }
    for i in 48..data.len { if data[i] > 2 { return false; } }
    var next = world::create_tall(data[9]); next.generator = u32_at(data, 28); next.seed = u32_at(data, 32);
    var cursor: i64 = 48;
    for at in world::slots(next) {
        if !world::active(next, at) { continue; }
        for i in 4096 { next.chunks[at].blocks[i] = data[cursor + i]; } cursor += 4096;
    }
    world::mark_all(next); map = copy(next); return true;
}
fn save(path: const u8[:], map: world::Tall&) -> bool {
    var data: u8[>..] = []; return encode(map, data) && storage::parent_directories(path) && write_file_atomic(path, data);
}
fn load(path: const u8[:], map: world::Tall&) -> bool {
    var data: u8[>..] = []; data.resize(MAX_BYTES, 0);
    let n = fileio::read_bounded(path, data); return n >= 0 && decode(data[..n], map);
}
fn import_legacy(source: const u8[:], destination: const u8[:]) -> bool {
    if file_exists(destination) || is_dir(destination) { return false; }
    var raw: u8[>..] = []; raw.resize(331792, 0); let n = fileio::read_bounded(source, raw);
    var old = world::Map {}; if n < 0 || !storage::decode(raw[..n], old) { return false; }
    var next = world::create_tall(old.radius); next.generator = 0; next.seed = 0;
    let offset = world::pool_count(old.radius);
    for at in old.chunks.len { if world::active(old, at) { next.chunks[offset + at] = old.chunks[at]; } }
    world::mark_all(next); return save(destination, next);
}
