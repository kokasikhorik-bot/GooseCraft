import os;
import core from "../src/core";

fn coordinates() {
    var map = world::create_tall(1);
    for y in [-16, -1, 0, 15, 16, 31, 32, 47] {
        assert(world::set(map, -1, y, -1, 2) && world::get(map, -1, y, -1) == 2);
        let at = world::section_slot(map, -1, world::chunk_coord(y), -1);
        assert(world::chunk_y(map, at) == world::chunk_coord(y));
        assert(world::get(map.chunks[at], 15, y % 16, 15) == 2);
    }
    let before = copy(map);
    for y in [-17, 48] { assert(!world::set(map, 0, y, 0, 1) && world::get(map, 0, y, 0) == 0 && world::equal(map, before)); }
    for y in [-1, 0, 15, 16, 31, 32] {
        map = world::create_tall(1); map.dirty = [false; 324];
        assert(world::set(map, 8, y, 8, 1) && world::pending(map) == 2);
        let at = world::section_slot(map, 0, world::chunk_coord(y), 0);
        var halo = world::neighborhood(map, at);
        assert(world::get(halo, 8, y % 16, 8) == 1);
        let neighbor = world::section_slot(map, 0, world::chunk_coord(y) + (if y % 16 == 15 { 1 } else { -1 }), 0);
        var other = world::neighborhood(map, neighbor);
        assert(world::get(other, 8, if y % 16 == 15 { -1 } else { 16 }, 8) == 1);
    }
    // Adjacent vertical sections must not emit the internal joining face.
    map = world::create_tall(0); world::set(map, 8, 15, 8, 1); world::set(map, 8, 16, 8, 1);
    var total: i64 = 0;
    var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
    for cy in [0, 1] {
        var halo = world::neighborhood(map, world::section_slot(map, 0, cy, 0));
        vertices.clear(); indices.clear(); mesh::build_reference(halo, vertices, indices); total += indices.len / 6;
    }
    assert(total == 10);
}
fn physics() {
    var map = world::create_tall(0);
    for z in 16 { for x in 16 { world::set(map, x, -10, z, 1); world::set(map, x, 20, z, 1); } }
    var p = player::State { position: float3 { 8.5, 24.0, 8.5 } };
    for i in 120 { player::tick(map, p, player::Input {}); } assert(p.grounded && p.position.y == 21.0);
    p = player::State { position: float3 { 8.5, -5.0, 8.5 } };
    for i in 120 { player::tick(map, p, player::Input {}); } assert(p.grounded && p.position.y == -9.0);
    let hit = interaction::raycast(map, float3 { 4.5, 24.0, 4.5 }, float3 { 0.0, -1.0, 0.0 }, 6.0);
    assert(hit.found && hit.cell.y == 20 && interaction::place(map, hit, p.position, 2));
    assert(world::get(map, 4, 21, 4) == 2);
}
fn codec(base: const u8[:]) {
    var original = world::generate_tall(12345, 1); var raw: u8[>..] = [];
    assert(tall_store::encode(original, raw) && raw.len == 48 + 36 * 4096);
    var decoded = world::Tall {}; assert(tall_store::decode(raw, decoded) && world::equal(original, decoded));
    let before = copy(decoded);
    for size in [0, 8, 16, 47, raw.len - 1] { assert(!tall_store::decode(raw[..size], decoded) && world::equal(before, decoded)); }
    for at in [8, 9, 10, 11, 16, 20, 24, 28, 36, 47] {
        var bad = copy(raw); bad[at] ^= 128; tall_store::put(bad, 12, storage::checksum(bad));
        assert(!tall_store::decode(bad, decoded) && world::equal(before, decoded));
    }
    var bad = copy(raw); bad[48] = 3; tall_store::put(bad, 12, storage::checksum(bad));
    assert(!tall_store::decode(bad, decoded) && world::equal(before, decoded));
    let path = str(base, "/tall.gcw"); assert(tall_store::save(path, original) && tall_store::load(path, decoded));
    assert(world::equal(original, decoded));
    var old = terrain::generate(1, false, 4); let source = str(base, "/legacy.gcw");
    assert(storage::save(source, old)); let migrated = str(base, "/migrated.gcw");
    assert(tall_store::import_legacy(source, migrated) && !tall_store::import_legacy(source, migrated));
    assert(tall_store::load(migrated, decoded) && decoded.generator == 0 && decoded.seed == 0 && world::count(decoded) == 324);
    for at in old.chunks.len { assert(decoded.chunks[81 + at] == old.chunks[at]); }
    for at in world::slots(decoded) { if world::chunk_y(decoded, at) != 0 { assert(world::solid_count(decoded.chunks[at]) == 0); } }
    var check = world::Map {}; assert(storage::load(source, check) && world::equal(old, check));
    assert(!storage::load(migrated, check) && world::equal(old, check));
    var resident = residency::State {}; residency::update(decoded, resident, 0, 0, 2);
    assert(resident.desired == 100);
    while world::pending(decoded) > 0 { let at = residency::next(decoded, resident); assert(at >= 0); residency::complete(decoded, resident, at); }
    assert(resident.resident == 100 && decoded.chunks.len == 324);
}
fn main() {
    let argv = args(); assert(argv.len == 2);
    coordinates(); physics(); codec(argv[1]); print("headless tall: ok");
}
