import core from "../src/core";
import .support.surface;
import .support.triangles;
import math;

fn codec(radius: i64) {
    var map = terrain::generate(12345, false, radius);
    let count = (radius * 2 + 1) * (radius * 2 + 1);
    assert(world::valid(map) && world::count(map) == count && map.chunks.len == count);
    assert(bytes_of(map.chunks).len == count * 4096 && world::pending(map) == count);
    assert(world::lower(map) == -16 * radius && world::upper(map) == (radius + 1) * 16);
    for at in count {
        assert(world::slot(world::chunk_x(map, at), world::chunk_z(map, at), radius) == at);
        let generated = terrain::chunk(12345, world::chunk_x(map, at), world::chunk_z(map, at));
        assert(generated == map.chunks[at]);
    }
    var duplicate = copy(map);
    let original = world::get(map, -16 * radius, 0, -16 * radius);
    world::set(duplicate, -16 * radius, 0, -16 * radius, 0);
    assert(world::get(map, -16 * radius, 0, -16 * radius) == original); // Independent owner.
    var data: u8[>..] = []; assert(storage::encode(map, data));
    assert(data.len == count * 4096 + 16 && data[8] == 2 && data[9] == radius && data[10] == count);
    var loaded = world::Map {};
    assert(storage::decode(data, loaded) && world::equal(loaded, map));
    let before = copy(loaded);
    for length in [0, 8, 15, 16, 4096, data.len - 1] {
        assert(!storage::decode(data[..length], loaded) && world::equal(loaded, before));
    }
    data.push(0); assert(!storage::decode(data, loaded) && world::equal(loaded, before)); data.resize(data.len - 1, 0);
    let old = data[500]; data[500] = 3;
    let sum = storage::checksum(data); for i in 4 { data[12 + i] = (sum >> (8 * i)) as! u8; }
    assert(!storage::decode(data, loaded) && world::equal(loaded, before));
    data[500] = old; data[8] = 1;
    let sum_v1 = storage::checksum(data); for i in 4 { data[12 + i] = (sum_v1 >> (8 * i)) as! u8; }
    assert(!storage::decode(data, loaded) && world::equal(loaded, before)); // v1 must not accept large radii.
    map.radius = 5;
    var invalid: u8[>..] = []; assert(!storage::encode(map, invalid) && invalid.len == 0);
}

fn edits_and_movement() {
    var map = world::region(false, true, 4);
    for at in map.chunks.len { map.chunks[at] = world::flat_fixture(); }
    while world::pop_dirty(map) >= 0 {}
    world::set(map, 63, 2, 63, 2);
    assert(world::pending(map) == 3); // Own/+X/+Z, never diagonal.
    var seen: bool[81] = [false; 81];
    for i in 3 { let at = world::pop_dirty(map); assert(at >= 0 && !seen[at]); seen[at] = true; }
    assert(seen[world::slot(3, 3, 4)] && seen[world::slot(4, 3, 4)] && seen[world::slot(3, 4, 4)]);
    assert(!seen[world::slot(4, 4, 4)] && world::pending(map) == 0);
    world::set(map, -64, 2, -64, 2);
    assert(world::pending(map) == 1 && world::pop_dirty(map) == 0);
    assert(!world::set(map, -65, 0, 0, 1) && !world::set(map, 80, 0, 0, 1));
    var state = player::State { position: float3 { 31.5, 1.0, 5.5 }, yaw: 1.5707963 };
    for i in 120 { player::tick(map, state, player::Input { forward: 1.0 }); }
    assert(state.position.x > 35.0 && state.grounded && !player::collides(map, state.position));
    state = player::State { position: float3 { -47.5, 1.0, 5.5 }, yaw: -1.5707963 };
    for i in 120 { player::tick(map, state, player::Input { forward: 1.0 }); }
    assert(state.position.x < -51.0 && state.grounded);
    for y in 1..4 { world::set(map, 64, y, 5, 2); }
    let hit = interaction::raycast(map, float3 { 62.5, 2.5, 5.5 }, float3 { 1.0, 0.0, 0.0 }, 6.0);
    assert(hit.found && hit.cell == int3 { 64, 2, 5 });
    assert(interaction::place(map, hit, float3 { 60.0, 1.0, 5.5 }, 1));
    assert(world::get(map, 63, 2, 5) == 1 && interaction::remove(map, hit));
}

fn geometry() {
    var map = terrain::generate(12345, false, 4);
    for at in map.chunks.len {
        var halo = world::neighborhood(map, at);
        var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
        var expected: u32[24576] = [0; 24576];
        mesh::build_reference(halo, vertices, indices);
        surface::coverage(halo, vertices, indices, expected);
        vertices.clear(); indices.clear(); mesh::build(halo, vertices, indices); stitch::apply(vertices, indices);
        assert(triangles::coverage(vertices, indices, expected));
        assert(triangles::no_t_junctions(vertices, indices));
    }
    // Cross-chunk topology at distant seams, using bounded 3x3 patches rather
    // than a dense half-grid bitmap spanning the entire large world.
    for first in [-4, -1, 2] {
        var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
        for z in 3 { for x in 3 {
            var halo = world::neighborhood(map, world::slot(first + x, first + z, 4));
            var local: mesh::Vertex[>..] = []; var local_indices: u32[>..] = [];
            mesh::build(halo, local, local_indices); stitch::apply(local, local_indices);
            let offset = vertices.len as u32;
            for v in local { vertices.push(mesh::Vertex { v.position + float3 { x * 16, 0.0, z * 16 }, v.color }); }
            for index in local_indices { indices.push(offset + index); }
        } }
        assert(triangles::no_t_junctions(vertices, indices, 48));
    }
}

fn main() {
    codec(2); codec(3); codec(4); edits_and_movement(); geometry();
    print("headless large: ok");
}
