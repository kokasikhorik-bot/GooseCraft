// Own test fixture, not Minecraft terrain or a Minecraft block registry.
import std;
namespace world;

struct Chunk { blocks: u8[4096] = [0; 4096] }

// One growable tail owns all block storage; bounded metadata has no heap graph.
// A minimum 3x3 pool preserves diagnostic radius=0 center slot 4.
struct Map {
    dirty: bool[81] = [false; 81],
    radius: i64 = 1,
    revision: i64 = 0,
    chunks: Chunk[>..] = [Chunk {}; 9],
}

fn width(radius: i64) -> i64 { 2 * max(radius, 1) + 1 }
fn pool_count(radius: i64) -> i64 { width(radius) * width(radius) }
fn count(map: Map&) -> i64 { if map.radius == 0 { 1 } else { pool_count(map.radius) } }

fn valid(map: Map&) -> bool {
    map.radius >= 0 && map.radius <= 4 && map.chunks.len == pool_count(map.radius)
}

// The pinned compiler does not generate == for a growable-tail struct.
fn equal(a: Map&, b: Map&) -> bool {
    if a.radius != b.radius || a.revision != b.revision || a.dirty != b.dirty || a.chunks.len != b.chunks.len { return false; }
    for at in a.chunks.len { if a.chunks[at].blocks != b.chunks[at].blocks { return false; } }
    return true;
}

fn create(radius: i64) -> Map {
    assert(radius >= 0 && radius <= 4);
    var map = Map { radius: radius };
    map.chunks.resize(pool_count(radius), Chunk {});
    return map;
}

fn chunk_x(map: Map&, at: i64) -> i64 { at % width(map.radius) - max(map.radius, 1) }
fn chunk_z(map: Map&, at: i64) -> i64 { at / width(map.radius) - max(map.radius, 1) }

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

fn slot(cx: i64, cz: i64, radius: i64 = 1) -> i64 {
    let r = max(radius, 1);
    assert(cx >= -r && cx <= r && cz >= -r && cz <= r);
    cx + r + (cz + r) * width(radius)
}

fn active(map: Map&, at: i64) -> bool {
    assert(at >= 0 && at < map.chunks.len);
    map.radius != 0 || at == 4
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
    return get(map.chunks[slot(cx, cz, map.radius)], x - cx * 16, y, z - cz * 16);
}

fn sample(map: Map&, x: i64, y: i64, z: i64) -> u8 { get(map, x, y, z) }

fn mark(map: Map&, cx: i64, cz: i64) {
    if cx < -map.radius || cx > map.radius || cz < -map.radius || cz > map.radius { return; }
    map.dirty[slot(cx, cz, map.radius)] = true;
}

fn set(map: Map&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(map, x, y, z) || value > 2 { return false; }
    let cx = chunk_coord(x);
    let cz = chunk_coord(z);
    let lx = x - cx * 16;
    let lz = z - cz * 16;
    let at = slot(cx, cz, map.radius);
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

fn mark_all(map: Map&) {
    for at in 81 { map.dirty[at] = false; }
    for at in map.chunks.len { map.dirty[at] = active(map, at); }
}

fn pending(map: Map&) -> i64 {
    var count: i64 = 0;
    for at in map.chunks.len { if active(map, at) && map.dirty[at] { count++; } }
    return count;
}

fn pop_dirty(map: Map&) -> i64 {
    for at in map.chunks.len {
        if active(map, at) && map.dirty[at] { map.dirty[at] = false; return at; }
    }
    return -1;
}

fn solid_count(map: Map&) -> i64 {
    var count: i64 = 0;
    for at in map.chunks.len { if active(map, at) { count += solid_count(map.chunks[at]); } }
    return count;
}

fn region(single: bool, empty: bool, radius: i64 = 1) -> Map {
    var map = create(if single { 0 } else { radius });
    if !empty {
        for at in map.chunks.len { if active(map, at) { map.chunks[at] = flat_fixture(); } }
        map.chunks[slot(0, 0, map.radius)] = demo_fixture();
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

fn neighborhood<T>(map: T&, at: i64) -> Halo {
    assert(active(map, at));
    let ox = chunk_x(map, at) * 16;
    let oz = chunk_z(map, at) * 16;
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
