// Own test fixture, not Minecraft terrain or a Minecraft block registry.
import std;
namespace world;

struct Chunk { blocks: u8[4096] = [0; 4096] }

// Explicit fixed owners, with no heap graph or per-block allocations.
// Chunk coordinates -1..1, x-major inside each z row; center slot is 4.
struct Map {
    chunks: Chunk[9] = [Chunk {}; 9],
    dirty: bool[9] = [false; 9],
    radius: i64 = 1,
    revision: i64 = 0,
}

// Local coordinates -1..16: a bounded snapshot for neighbor-aware meshing.
struct Halo { blocks: u8[5832] = [0; 5832] }

fn contains(x: i64, y: i64, z: i64) -> bool {
    x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16
}

fn index(x: i64, y: i64, z: i64) -> i64 {
    assert(contains(x, y, z));
    x + 16 * (z + 16 * y)
}

fn set(chunk: Chunk&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(x, y, z) { return false; }
    chunk.blocks[index(x, y, z)] = value;
    return true;
}

fn get(chunk: Chunk&, x: i64, y: i64, z: i64) -> u8 {
    chunk.blocks[index(x, y, z)]
}

fn sample(chunk: Chunk&, x: i64, y: i64, z: i64) -> u8 {
    if !contains(x, y, z) { return 0; }
    return get(chunk, x, y, z);
}

fn lower(chunk: Chunk&) -> i64 { 0 }
fn upper(chunk: Chunk&) -> i64 { 16 }

// Goose / truncates, while % is Euclidean (never negative).
fn chunk_coord(value: i64) -> i64 { div_euclid(value, 16) }

fn slot(cx: i64, cz: i64) -> i64 {
    assert(cx >= -1 && cx <= 1 && cz >= -1 && cz <= 1);
    cx + 1 + (cz + 1) * 3
}

fn active(map: Map&, at: i64) -> bool {
    assert(at >= 0 && at < 9);
    map.radius == 1 || at == 4
}

fn lower(map: Map&) -> i64 { -map.radius * 16 }
fn upper(map: Map&) -> i64 { (map.radius + 1) * 16 }

fn contains(map: Map&, x: i64, y: i64, z: i64) -> bool {
    x >= lower(map) && x < upper(map) && z >= lower(map) && z < upper(map) && y >= 0 && y < 16
}

fn get(map: Map&, x: i64, y: i64, z: i64) -> u8 {
    if !contains(map, x, y, z) { return 0; }
    let cx = chunk_coord(x);
    let cz = chunk_coord(z);
    return get(map.chunks[slot(cx, cz)], x - cx * 16, y, z - cz * 16);
}

fn sample(map: Map&, x: i64, y: i64, z: i64) -> u8 { get(map, x, y, z) }

fn mark(map: Map&, cx: i64, cz: i64) {
    if cx < -map.radius || cx > map.radius || cz < -map.radius || cz > map.radius { return; }
    map.dirty[slot(cx, cz)] = true;
}

fn set(map: Map&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(map, x, y, z) || value > 2 { return false; }
    let cx = chunk_coord(x);
    let cz = chunk_coord(z);
    let lx = x - cx * 16;
    let lz = z - cz * 16;
    let at = slot(cx, cz);
    if get(map.chunks[at], lx, y, lz) == value { return true; }
    set(map.chunks[at], lx, y, lz, value);
    mark(map, cx, cz);
    if lx == 0 { mark(map, cx - 1, cz); }
    if lx == 15 { mark(map, cx + 1, cz); }
    if lz == 0 { mark(map, cx, cz - 1); }
    if lz == 15 { mark(map, cx, cz + 1); }
    map.revision++;
    return true;
}

fn mark_all(map: Map&) { for at in 9 { map.dirty[at] = active(map, at); } }

fn pending(map: Map&) -> i64 {
    var count: i64 = 0;
    for at in 9 { if active(map, at) && map.dirty[at] { count++; } }
    return count;
}

fn pop_dirty(map: Map&) -> i64 {
    for at in 9 {
        if active(map, at) && map.dirty[at] { map.dirty[at] = false; return at; }
    }
    return -1;
}

fn solid_count(map: Map&) -> i64 {
    var count: i64 = 0;
    for at in 9 { if active(map, at) { count += solid_count(map.chunks[at]); } }
    return count;
}

fn region(single: bool, empty: bool) -> Map {
    var map = Map { radius: if single { 0 } else { 1 } };
    if !empty {
        for at in 9 { if active(map, at) { map.chunks[at] = flat_fixture(); } }
        map.chunks[4] = demo_fixture();
        if !single {
            for y in 1..5 { set(map, 15, y, 9, 2); set(map, 16, y, 9, 2); }
            for y in 1..4 { set(map, -8, y, -8, 2); }
            for y in 1..7 { set(map, 24, y, 24, 2); }
        }
    }
    map.revision = 0;
    mark_all(map);
    return map;
}

fn get(halo: Halo&, x: i64, y: i64, z: i64) -> u8 {
    assert(x >= -1 && x <= 16 && y >= -1 && y <= 16 && z >= -1 && z <= 16);
    halo.blocks[(x + 1) + 18 * ((z + 1) + 18 * (y + 1))]
}

fn sample(halo: Halo&, x: i64, y: i64, z: i64) -> u8 { get(halo, x, y, z) }

fn neighborhood(map: Map&, at: i64) -> Halo {
    assert(active(map, at));
    let ox = (at % 3 - 1) * 16;
    let oz = (at / 3 - 1) * 16;
    var halo = Halo {};
    for y in -1..17 { for z in -1..17 { for x in -1..17 {
        halo.blocks[(x + 1) + 18 * ((z + 1) + 18 * (y + 1))] = get(map, ox + x, y, oz + z);
    } } }
    return halo;
}

fn solid_count(chunk: Chunk&) -> i64 {
    var count: i64 = 0;
    for value in chunk.blocks { if value != 0 { count++; } }
    return count;
}

fn flat_fixture() -> Chunk {
    var chunk = Chunk {};
    for z in 16 {
        for x in 16 { assert(set(chunk, x, 0, z, 1)); }
    }
    return chunk;
}

fn demo_fixture() -> Chunk {
    var chunk = flat_fixture();
    for y in 1..5 { assert(set(chunk, 5, y, 5, 2)); }
    for y in 1..8 { assert(set(chunk, 10, y, 9, 2)); }
    return chunk;
}
