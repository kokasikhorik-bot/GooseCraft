import core from "../src/core";
import .support.surface;
import math;

fn drain(map: world::Map&) { while world::pop_dirty(map) >= 0 {} }

fn surfaces(map: world::Map&, expected_faces: i64, expected_quads: i64 = -1) {
    var count: i64 = 0;
    var quads: i64 = 0;
    for at in 9 {
        if !world::active(map, at) { continue; }
        var halo = world::neighborhood(map, at);
        var reference: mesh::Vertex[>..] = [];
        var greedy: mesh::Vertex[>..] = [];
        var old_indices: u32[>..] = [];
        var new_indices: u32[>..] = [];
        mesh::build_reference(halo, reference, old_indices);
        mesh::build(halo, greedy, new_indices);
        var a: u32[24576] = [0; 24576];
        var b: u32[24576] = [0; 24576];
        let old_count = surface::coverage(halo, reference, old_indices, a);
        let new_count = surface::coverage(halo, greedy, new_indices, b);
        assert(a == b && old_count == new_count);
        count += new_count; quads += greedy.len / 4;
    }
    assert(count == expected_faces);
    if expected_quads >= 0 { assert(quads == expected_quads); }
}

fn coordinates() {
    assert(world::chunk_coord(-17) == -2 && world::chunk_coord(-16) == -1);
    assert(world::chunk_coord(-1) == -1 && world::chunk_coord(0) == 0);
    assert(world::chunk_coord(15) == 0 && world::chunk_coord(16) == 1);
    var map = world::region(false, true);
    assert(world::pending(map) == 9);
    let positions: i64[3][6] = [[-16, 0, -16], [-1, 1, -1], [0, 2, 0], [15, 3, 15], [16, 4, 16], [31, 15, 31]];
    for i in 6 {
        let p = positions[i];
        assert(world::set(map, p[0], p[1], p[2], (i % 2 + 1) as u8));
    }
    for i in 6 {
        let p = positions[i];
        assert(world::get(map, p[0], p[1], p[2]) == (i % 2 + 1) as u8);
    }
    assert(world::solid_count(map) == 6);
    assert(!world::set(map, -17, 0, 0, 1) && !world::set(map, 32, 0, 0, 1));
    assert(!world::set(map, 0, -1, 0, 1) && !world::set(map, 0, 16, 0, 1));
    assert(!world::set(map, 0, 0, 0, 3));
    var center = world::neighborhood(map, 4);
    assert(world::get(center, -1, 1, -1) == 2);
    assert(world::get(center, 16, 4, 16) == 1);
    assert(world::get(center, 0, -1, 0) == 0);
    var fixture = world::region(false, false);
    assert(world::solid_count(fixture) == 2332);
}

fn invalidation() {
    var map = world::region(false, true);
    drain(map); assert(world::pending(map) == 0);
    world::set(map, 10, 2, 10, 1);
    assert(world::pending(map) == 1 && world::pop_dirty(map) == 4);
    let revision = map.revision;
    world::set(map, 10, 2, 10, 1);
    assert(world::pending(map) == 0 && map.revision == revision);
    world::set(map, 15, 2, 10, 1);
    world::set(map, 15, 3, 10, 1);
    assert(world::pending(map) == 2);
    assert(world::pop_dirty(map) == 4 && world::pop_dirty(map) == 5);
    world::set(map, 15, 2, 15, 1);
    assert(world::pending(map) == 3);
    // A two-chunk frame budget leaves exactly one, without marking diagonal 8.
    assert(world::pop_dirty(map) == 4 && world::pop_dirty(map) == 5);
    assert(world::pending(map) == 1 && world::pop_dirty(map) == 7);
    assert(world::pop_dirty(map) == -1);
    world::set(map, -16, 2, -16, 1);
    assert(world::pending(map) == 1 && world::pop_dirty(map) == 0);
    world::set(map, -1, 2, -1, 1);
    assert(world::pending(map) == 3);
    assert(world::pop_dirty(map) == 0 && world::pop_dirty(map) == 1 && world::pop_dirty(map) == 3);
}

fn seams() {
    var map = world::region(false, true);
    world::set(map, 15, 2, 8, 1); world::set(map, 16, 2, 8, 2);
    surfaces(map, 10, 10); // Shared X seam has no internal face.
    map = world::region(false, true);
    world::set(map, -1, 2, 8, 1); world::set(map, 0, 2, 8, 1);
    surfaces(map, 10, 10);
    map = world::region(false, true);
    world::set(map, 8, 2, -1, 1); world::set(map, 8, 2, 0, 2);
    surfaces(map, 10, 10);
    map = world::region(false, true);
    for at in 9 { map.chunks[at] = world::flat_fixture(); }
    surfaces(map, 4800, 30); // 48x48 slab, instead of nine closed 16x16 slabs.
}

fn walking() {
    var map = world::region(false, true);
    for at in 9 { map.chunks[at] = world::flat_fixture(); }
    var p = player::State { position: float3 { 15.5, 1.0, 5.5 }, yaw: 1.5707963 };
    for i in 60 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(p.position.x > 17.0 && abs(p.position.y - 1.0) < 0.001 && p.grounded);
    p = player::State { position: float3 { 0.5, 1.0, 5.5 }, yaw: -1.5707963 };
    for i in 60 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(p.position.x < -1.0 && p.grounded);
    p = player::State { position: float3 { 5.5, 1.0, 15.5 }, yaw: 3.1415926 };
    for i in 60 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(p.position.z > 17.0 && p.grounded);
    for y in 1..4 { world::set(map, 16, y, 5, 2); }
    p = player::State { position: float3 { 15.5, 1.0, 5.5 }, yaw: 1.5707963 };
    for i in 60 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(abs(p.position.x - (16.0 - player::RADIUS)) < 0.001);
    assert(!player::collides(map, p.position));
    let hit = interaction::raycast(map, float3 { 14.5, 2.5, 5.5 }, float3 { 1.0, 0.0, 0.0 }, 6.0);
    assert(hit.found && hit.cell == int3 { 16, 2, 5 } && abs(hit.distance - 1.5) < 0.001);
    assert(interaction::place(map, hit, float3 { 10.5, 1.0, 10.5 }, 1));
    assert(world::get(map, 15, 2, 5) == 1);
    assert(interaction::remove(map, hit) && world::get(map, 16, 2, 5) == 0);
    for y in 1..4 { world::set(map, -1, y, 5, 2); }
    p = player::State { position: float3 { 0.5, 1.0, 5.5 }, yaw: -1.5707963 };
    for i in 60 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(abs(p.position.x - player::RADIUS) < 0.001 && !player::collides(map, p.position));
    let negative = interaction::raycast(map, float3 { 1.5, 2.5, 5.5 }, float3 { -1.0, 0.0, 0.0 }, 6.0);
    assert(negative.found && negative.cell == int3 { -1, 2, 5 } && abs(negative.distance - 1.5) < 0.001);
    p = player::State { position: float3 { 31.5, 1.0, 5.5 }, yaw: 1.5707963 };
    for i in 120 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(abs(p.position.x - (32.0 - player::RADIUS)) < 0.001 && p.grounded);
    p = player::State { position: float3 { -15.5, 1.0, 5.5 }, yaw: -1.5707963 };
    for i in 120 { player::tick(map, p, player::Input { forward: 1.0 }); }
    assert(abs(p.position.x - (-16.0 + player::RADIUS)) < 0.001 && p.grounded);
}

fn main() {
    coordinates(); invalidation(); seams(); walking();
    print("headless region: ok");
}
