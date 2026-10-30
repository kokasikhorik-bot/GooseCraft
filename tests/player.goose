import core from "../src/core";
import math;
import vec;

fn near(a: f32, b: f32) { assert(abs(a - b) < 0.001); }

fn movement() {
    var chunk = world::flat_fixture();
    var p = player::State {};
    for i in 120 { player::tick(chunk, p, player::Input {}); }
    near(p.position.y, 1.0);
    assert(p.grounded && !player::collides(chunk, p.position));
    let start = p.position;
    for i in 120 { player::tick(chunk, p, player::Input { forward: 1.0 }); }
    near(p.position.z, start.z - 4.2);
    near(p.position.x, start.x);
    var diagonal = player::State {};
    for i in 120 { player::tick(chunk, diagonal, player::Input { forward: 1.0, strafe: 1.0 }); }
    near(length(diagonal.position - start), 4.2);
    player::look(p, 1000.0, 10000.0);
    near(length(player::direction(p)), 1.0);
    near(p.pitch, -1.5);
    player::look(p, 0.0, -10000.0);
    near(p.pitch, 1.5);
    // Island boundaries contain walking even without a wall of blocks.
    for i in 1000 { player::tick(chunk, diagonal, player::Input { strafe: 1.0 }); }
    near(diagonal.position.x, 16.0 - player::RADIUS);
    for i in 1000 { player::tick(chunk, diagonal, player::Input { strafe: -1.0 }); }
    near(diagonal.position.x, player::RADIUS);
    // Positive yaw turns right: local forward becomes world +X.
    p = player::State { yaw: 1.5707963 };
    player::tick(chunk, p, player::Input { forward: 1.0 });
    assert(p.position.x > 10.5);
    near(p.position.z, 13.5);
}

fn collisions() {
    var chunk = world::flat_fixture();
    for y in 1..5 { for z in 16 { world::set(chunk, 12, y, z, 2); } }
    var p = player::State {};
    for i in 120 { player::tick(chunk, p, player::Input { forward: 1.0, strafe: 1.0 }); }
    near(p.position.x, 12.0 - player::RADIUS);
    assert(p.position.z < 12.0 && !player::collides(chunk, p.position));
    // Jump, refuse a second airborne jump, land on the same floor.
    p = player::State {};
    player::tick(chunk, p, player::Input {});
    player::tick(chunk, p, player::Input { jump: true });
    assert(p.position.y > 1.0 && !p.grounded && p.jumps == 1);
    for i in 20 { player::tick(chunk, p, player::Input { jump: true }); }
    assert(p.jumps == 1);
    for i in 120 { player::tick(chunk, p, player::Input {}); }
    near(p.position.y, 1.0);
    assert(p.grounded);
    // A low ceiling cancels upward velocity without placing the head in it.
    world::set(chunk, 10, 3, 13, 2);
    player::tick(chunk, p, player::Input { jump: true });
    for i in 8 { player::tick(chunk, p, player::Input {}); }
    assert(p.position.y + player::HEIGHT <= 3.0001);
    assert(p.velocity_y <= 0.0 && !player::collides(chunk, p.position));
    world::set(chunk, 10, 3, 13, 0);
    p = player::State { position: float3 { 10.5, 14.0, 13.5 }, velocity_y: -40.0 };
    for i in 60 { player::tick(chunk, p, player::Input {}); }
    near(p.position.y, 1.0);
    assert(p.grounded && !player::collides(chunk, p.position));
    // A hole has no invisible floor. Falling below the island respawns.
    world::set(chunk, 8, 0, 8, 0);
    p = player::State { position: float3 { 8.5, 1.0, 8.5 } };
    for i in 180 { player::tick(chunk, p, player::Input {}); }
    assert(p.respawns == 1 && p.grounded);
    near(p.position.x, 10.5);
    // Spawn safety after the player has placed a block at the spawn point.
    world::set(chunk, 10, 1, 13, 2);
    player::respawn(chunk, p);
    assert(!player::collides(chunk, p.position));
    near(p.position.y, 2.0);
}

fn selection() {
    var chunk = world::Chunk {};
    world::set(chunk, 8, 8, 8, 2);
    let axes: float3[6] = [float3 { 1.0, 0.0, 0.0 }, float3 { -1.0, 0.0, 0.0 },
                           float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, -1.0, 0.0 },
                           float3 { 0.0, 0.0, 1.0 }, float3 { 0.0, 0.0, -1.0 }];
    for axis in axes {
        let hit = interaction::raycast(chunk, float3 { 8.5, 8.5, 8.5 } - axis * 3.0, axis * 2.0, 6.0);
        assert(hit.found && hit.cell == int3 { 8, 8, 8 });
        near(hit.distance, 2.5);
        assert(hit.normal == int3 { (-axis.x) as i32, (-axis.y) as i32, (-axis.z) as i32 });
    }
    let origin = float3 { 8.5, 8.5, 12.0 };
    assert(!interaction::raycast(chunk, origin, float3 { 0.0, 0.0, -1.0 }, 2.99).found);
    assert(interaction::raycast(chunk, origin, float3 { 0.0, 0.0, -1.0 }, 3.0).found);
    assert(!interaction::raycast(chunk, origin, float3_0, 6.0).found);
    assert(!interaction::raycast(chunk, origin, float3 { 0.0, 1.0, 0.0 }, 6.0).found);
    // Crossing the island boundary from a negative world coordinate.
    world::set(chunk, 0, 2, 2, 1);
    let boundary = interaction::raycast(chunk, float3 { -1.0, 2.5, 2.5 }, float3 { 1.0, 0.0, 0.0 }, 6.0);
    assert(boundary.found && boundary.normal.x == -1);
    near(boundary.distance, 1.0);
    // Starting on a grid plane and travelling in the negative direction.
    let plane = interaction::raycast(chunk, float3 { 9.0, 8.5, 8.5 }, float3 { -1.0, 0.0, 0.0 }, 6.0);
    assert(plane.found && plane.normal.x == 1);
    near(plane.distance, 0.0);
}

fn editing() {
    var chunk = world::flat_fixture();
    let origin = float3 { 8.5, 3.0, 8.5 };
    let hit = interaction::raycast(chunk, origin, float3 { 0.0, -1.0, 0.0 }, 6.0);
    assert(hit.found && hit.cell == int3 { 8, 0, 8 });
    // Refuse to build inside the player, outside the world, or over a block.
    assert(!interaction::place(chunk, hit, float3 { 8.5, 1.0, 8.5 }, 2));
    assert(!interaction::place(chunk, hit, origin, 0));
    assert(!interaction::place(chunk, interaction::Hit {}, origin, 2));
    assert(interaction::place(chunk, hit, origin, 2));
    assert(!interaction::place(chunk, hit, origin, 2));
    assert(world::solid_count(chunk) == 257);
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    mesh::build(chunk, vertices, indices);
    assert(indices.len > 6 * 6 && indices.len < (576 + 4) * 6);
    assert(interaction::remove(chunk, hit));
    assert(!interaction::remove(chunk, hit));
    assert(world::solid_count(chunk) == 256);
    let edge = interaction::Hit { found: true, cell: int3 { 0, 0, 0 }, normal: int3 { -1, 0, 0 } };
    assert(!interaction::place(chunk, edge, origin, 1));
    let inside = interaction::raycast(chunk, float3 { 0.5, 0.5, 0.5 }, float3 { 1.0, 0.0, 0.0 }, 6.0);
    assert(inside.found && !interaction::place(chunk, inside, origin, 2));
}

fn obstacle_course() {
    var chunk = world::flat_fixture();
    for z in 2..14 {
        for x in 2..14 {
            if (x * 7 + z * 11) % 13 == 0 && (x != 10 || z != 13) {
                for y in 1..4 { world::set(chunk, x, y, z, 2); }
            }
        }
    }
    var state = player::State {};
    // Changing headings, both signs of every horizontal axis, corners and
    // jumps against a field of obstacles. Check safety after every tick.
    for i in 8000 {
        player::look(state, 7.0, 0.0);
        player::tick(chunk, state, player::Input {
            forward: if (i / 240) % 2 == 0 { 1.0 } else { -1.0 },
            strafe: if (i / 90) % 3 == 0 { 1.0 } else { -1.0 },
            jump: i % 83 == 0,
        });
        assert(!player::collides(chunk, state.position));
        assert(state.position.x >= player::RADIUS && state.position.x <= 16.0 - player::RADIUS);
        assert(state.position.z >= player::RADIUS && state.position.z <= 16.0 - player::RADIUS);
        assert(is_finite(state.position.y));
    }
}

fn main() {
    movement(); collisions(); selection(); editing(); obstacle_course();
    print("headless player: ok");
}
