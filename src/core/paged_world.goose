import .world;
namespace world;

// Disk index has no chunk payloads. Counts include currently unloaded pages.
struct PageIndex {
    radius: i64 = 4, generator: i64 = 1, seed: u32 = 12345, serial: u32 = 0,
    generations: u32[81] = [0; 81], hashes: u32[81] = [0; 81], solids: i64[81] = [0; 81],
}

struct Paged {
    radius: i64 = 4, revision: i64 = 0,
    index: PageIndex = PageIndex {},
    dirty: bool[81] = [false; 81], changed: bool[81] = [false; 81],
    locations: i64[81] = [-1; 81], owners: i64[49] = [-1; 49],
    resident: i64 = 0, peak: i64 = 0, reads: i64 = 0, generated: i64 = 0,
    evictions: i64 = 0, commits: i64 = 0, page_writes: i64 = 0,
    center_x: i64 = 100, center_z: i64 = 100, cpu_radius: i64 = 0,
    chunks: Chunk[49] = [Chunk {}; 49],
}

fn slots(map: Map&) -> i64 { map.chunks.len }
fn slots(map: Paged&) -> i64 { pool_count(map.radius) }
fn resident_count(map: Map&) -> i64 { count(map) }
fn resident_count(map: Paged&) -> i64 { map.resident }
fn count(map: Paged&) -> i64 { if map.radius == 0 { 1 } else { slots(map) } }
fn active(map: Paged&, at: i64) -> bool {
    assert(at >= 0 && at < slots(map)); map.radius != 0 || at == 4
}
fn chunk_x(map: Paged&, at: i64) -> i64 { at % width(map.radius) - max(map.radius, 1) }
fn chunk_z(map: Paged&, at: i64) -> i64 { at / width(map.radius) - max(map.radius, 1) }
fn chunk_y(map: Paged&, at: i64) -> i64 { 0 }
fn lower_y(map: Paged&) -> i64 { 0 }
fn upper_y(map: Paged&) -> i64 { 16 }
fn view_height(map: Paged&) -> f32 { 0.0 }
fn lower(map: Paged&) -> i64 { -map.radius * 16 }
fn upper(map: Paged&) -> i64 { (map.radius + 1) * 16 }
fn contains(map: Paged&, x: i64, y: i64, z: i64) -> bool {
    x >= lower(map) && x < upper(map) && z >= lower(map) && z < upper(map) && y >= 0 && y < 16
}
fn get(map: Paged&, x: i64, y: i64, z: i64) -> u8 {
    if !contains(map, x, y, z) { return 0; }
    let cx = chunk_coord(x); let cz = chunk_coord(z);
    let at = slot(cx, cz, map.radius); let pool = map.locations[at];
    assert(pool >= 0 && pool < 49); // Missing data must never masquerade as air.
    return get(map.chunks[pool], x - cx * 16, y, z - cz * 16);
}
fn sample(map: Paged&, x: i64, y: i64, z: i64) -> u8 { get(map, x, y, z) }
fn mark(map: Paged&, cx: i64, cz: i64) {
    if cx < -map.radius || cx > map.radius || cz < -map.radius || cz > map.radius { return; }
    map.dirty[slot(cx, cz, map.radius)] = true;
}
fn set(map: Paged&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(map, x, y, z) || value > 2 { return false; }
    let cx = chunk_coord(x); let cz = chunk_coord(z);
    let lx = x - cx * 16; let lz = z - cz * 16;
    let at = slot(cx, cz, map.radius); let pool = map.locations[at];
    assert(pool >= 0 && pool < 49);
    let before = get(map.chunks[pool], lx, y, lz);
    if before == value { return true; }
    set(map.chunks[pool], lx, y, lz, value);
    map.index.solids[at] += (if value != 0 { 1 } else { 0 }) - (if before != 0 { 1 } else { 0 });
    map.changed[at] = true; map.revision++;
    mark(map, cx, cz);
    if lx == 0 { mark(map, cx - 1, cz); } if lx == 15 { mark(map, cx + 1, cz); }
    if lz == 0 { mark(map, cx, cz - 1); } if lz == 15 { mark(map, cx, cz + 1); }
    return true;
}
fn solid_count(map: Paged&) -> i64 {
    var n: i64 = 0; for at in slots(map) { if active(map, at) { n += map.index.solids[at]; } } return n;
}
fn pending(map: Paged&) -> i64 {
    var n: i64 = 0; for at in slots(map) { if active(map, at) && map.dirty[at] { n++; } } return n;
}
