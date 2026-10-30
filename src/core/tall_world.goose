// Four 16^3 sections per column, including negative Y. Fully resident backend.
import .world;
import .terrain;
namespace world;

struct Tall {
    dirty: bool[324] = [false; 324], radius: i64 = 1, revision: i64 = 0,
    generator: i64 = 2, seed: u32 = 12345,
    chunks: Chunk[>..] = [Chunk {}; 36],
}
fn create_tall(radius: i64) -> Tall {
    assert(radius >= 0 && radius <= 4);
    var map = Tall { radius: radius }; map.chunks.resize(4 * pool_count(radius), Chunk {}); return map;
}
fn valid(map: Tall&) -> bool {
    map.radius >= 0 && map.radius <= 4 && map.chunks.len == 4 * pool_count(map.radius) &&
        (map.generator == 2 || (map.generator == 0 && map.seed == 0))
}
fn equal(a: Tall&, b: Tall&) -> bool {
    if a.dirty != b.dirty || a.radius != b.radius || a.revision != b.revision || a.generator != b.generator || a.seed != b.seed || a.chunks.len != b.chunks.len { return false; }
    for at in a.chunks.len { if a.chunks[at] != b.chunks[at] { return false; } } return true;
}
fn slots(map: Tall&) -> i64 { map.chunks.len }
fn count(map: Tall&) -> i64 { 4 * (if map.radius == 0 { 1 } else { pool_count(map.radius) }) }
fn resident_count(map: Tall&) -> i64 { count(map) }
fn active(map: Tall&, at: i64) -> bool {
    assert(at >= 0 && at < slots(map)); map.radius != 0 || at % 9 == 4
}
fn chunk_x(map: Tall&, at: i64) -> i64 { at % pool_count(map.radius) % width(map.radius) - max(map.radius, 1) }
fn chunk_z(map: Tall&, at: i64) -> i64 { at % pool_count(map.radius) / width(map.radius) - max(map.radius, 1) }
fn chunk_y(map: Tall&, at: i64) -> i64 { at / pool_count(map.radius) - 1 }
fn lower(map: Tall&) -> i64 { -map.radius * 16 }
fn upper(map: Tall&) -> i64 { (map.radius + 1) * 16 }
fn lower_y(map: Tall&) -> i64 { -16 }
fn upper_y(map: Tall&) -> i64 { 48 }
fn view_height(map: Tall&) -> f32 { 16.0 }
fn section_slot(map: Tall&, cx: i64, cy: i64, cz: i64) -> i64 {
    assert(cy >= -1 && cy <= 2); (cy + 1) * pool_count(map.radius) + slot(cx, cz, map.radius)
}
fn contains(map: Tall&, x: i64, y: i64, z: i64) -> bool {
    x >= lower(map) && x < upper(map) && z >= lower(map) && z < upper(map) && y >= lower_y(map) && y < upper_y(map)
}
fn get(map: Tall&, x: i64, y: i64, z: i64) -> u8 {
    if !contains(map, x, y, z) { return 0; }
    return get(map.chunks[section_slot(map, chunk_coord(x), chunk_coord(y), chunk_coord(z))], x % 16, y % 16, z % 16);
}
fn sample(map: Tall&, x: i64, y: i64, z: i64) -> u8 { get(map, x, y, z) }
fn mark(map: Tall&, cx: i64, cy: i64, cz: i64) {
    if cx < -map.radius || cx > map.radius || cz < -map.radius || cz > map.radius || cy < -1 || cy > 2 { return; }
    map.dirty[section_slot(map, cx, cy, cz)] = true;
}
fn set(map: Tall&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(map, x, y, z) || value > 2 { return false; }
    let cx = chunk_coord(x); let cy = chunk_coord(y); let cz = chunk_coord(z);
    let at = section_slot(map, cx, cy, cz);
    if get(map.chunks[at], x % 16, y % 16, z % 16) == value { return true; }
    set(map.chunks[at], x % 16, y % 16, z % 16, value); mark(map, cx, cy, cz); map.revision++;
    if x % 16 == 0 { mark(map, cx - 1, cy, cz); } if x % 16 == 15 { mark(map, cx + 1, cy, cz); }
    if y % 16 == 0 { mark(map, cx, cy - 1, cz); } if y % 16 == 15 { mark(map, cx, cy + 1, cz); }
    if z % 16 == 0 { mark(map, cx, cy, cz - 1); } if z % 16 == 15 { mark(map, cx, cy, cz + 1); }
    return true;
}
fn mark_all(map: Tall&) {
    map.dirty = [false; 324]; for at in slots(map) { map.dirty[at] = active(map, at); }
}
fn pending(map: Tall&) -> i64 {
    var n: i64 = 0; for at in slots(map) { if active(map, at) && map.dirty[at] { n++; } } return n;
}
fn solid_count(map: Tall&) -> i64 {
    var n: i64 = 0; for at in slots(map) { if active(map, at) { n += solid_count(map.chunks[at]); } } return n;
}
fn tall_height(seed: u32, x: i64, z: i64) -> i64 {
    12 + 2 * terrain::height(seed, x, z) + terrain::noise(seed ^ 0x68bc21eb, x, z, 32) * 8 / 256
}
fn generate_tall(seed: u32, radius: i64 = 1) -> Tall {
    var map = create_tall(radius); map.seed = seed;
    for at in slots(map) {
        if !active(map, at) { continue; }
        let ox = chunk_x(map, at) * 16; let oy = chunk_y(map, at) * 16; let oz = chunk_z(map, at) * 16;
        for z in 16 { for x in 16 {
            let h = tall_height(seed, ox + x, oz + z);
            for y in 16 { if oy + y < h { set(map.chunks[at], x, y, z, if oy + y == h - 1 { 1 } else { 2 }); } }
        } }
    }
    mark_all(map); return map;
}
