// Fixed-step first-person movement. No graphics, OS input or wall clock here.
import math;
import std;
import vec;
import .world;
namespace player;

let RADIUS: f32 = 0.3;
let HEIGHT: f32 = 1.8;
let EYE: f32 = 1.62;
let STEP: f32 = 1.0 / 120.0;

struct State {
    position: float3 = float3 { 10.5, 1.0, 13.5 },
    velocity_y: f32 = 0.0,
    yaw: f32 = 0.0,
    pitch: f32 = 0.0,
    grounded: bool = false,
    ticks: i64 = 0,
    jumps: i64 = 0,
    respawns: i64 = 0,
}

struct Input { forward: f32 = 0.0, strafe: f32 = 0.0, jump: bool = false }

fn eye(state: State&) -> float3 { state.position + float3 { 0.0, EYE, 0.0 } }

fn direction(state: State&) -> float3 {
    float3 { sin(state.yaw) * cos(state.pitch), sin(state.pitch),
             -cos(state.yaw) * cos(state.pitch) }
}

fn look(state: State&, dx: f32, dy: f32) {
    state.yaw = (state.yaw + dx * 0.0025) % 6.2831853;
    state.pitch = clamp(state.pitch - dy * 0.0025, -1.5, 1.5);
}

fn overlaps_cell(p: float3, x: i64, y: i64, z: i64) -> bool {
    p.x + RADIUS > x && p.x - RADIUS < x + 1 &&
    p.y + HEIGHT > y && p.y < y + 1 &&
    p.z + RADIUS > z && p.z - RADIUS < z + 1
}

fn collides<T>(chunk: T&, p: float3) -> bool {
    for y in clamp(floor(p.y) as i64, world::lower_y(chunk), world::upper_y(chunk) - 1)..clamp(floor(p.y + HEIGHT) as i64, world::lower_y(chunk), world::upper_y(chunk) - 1) + 1 {
        for z in clamp(floor(p.z - RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1)..clamp(floor(p.z + RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) + 1 {
            for x in clamp(floor(p.x - RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1)..clamp(floor(p.x + RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) + 1 {
                if world::get(chunk, x, y, z) != 0 && overlaps_cell(p, x, y, z) { return true; }
            }
        }
    }
    return false;
}

// Each fixed tick moves less than one voxel. Resolve each axis against all
// intersected cells, so neither walking nor terminal-velocity falls tunnel.
fn move_axis<T>(chunk: T&, state: State&, axis: i64, amount: f32) -> bool {
    var p = state.position;
    if axis == 0 { p.x = clamp(p.x + amount, world::lower(chunk) + RADIUS, world::upper(chunk) - RADIUS); }
    if axis == 1 { p.y += amount; }
    if axis == 2 { p.z = clamp(p.z + amount, world::lower(chunk) + RADIUS, world::upper(chunk) - RADIUS); }
    var blocked = false;
    let lo = int3 { clamp(floor(p.x - RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) as i32,
                    clamp(floor(p.y) as i64, world::lower_y(chunk), world::upper_y(chunk) - 1) as i32,
                    clamp(floor(p.z - RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) as i32 };
    let hi = int3 { clamp(floor(p.x + RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) as i32,
                    clamp(floor(p.y + HEIGHT) as i64, world::lower_y(chunk), world::upper_y(chunk) - 1) as i32,
                    clamp(floor(p.z + RADIUS) as i64, world::lower(chunk), world::upper(chunk) - 1) as i32 };
    for y in lo.y..hi.y + 1 {
        for z in lo.z..hi.z + 1 {
            for x in lo.x..hi.x + 1 {
                if world::get(chunk, x, y, z) == 0 || !overlaps_cell(p, x, y, z) { continue; }
                blocked = true;
                if axis == 0 { p.x = if amount > 0.0 { x - RADIUS } else { x + 1.0 + RADIUS }; }
                if axis == 1 { p.y = if amount > 0.0 { y - HEIGHT } else { y + 1.0 }; }
                if axis == 2 { p.z = if amount > 0.0 { z - RADIUS } else { z + 1.0 + RADIUS }; }
            }
        }
    }
    state.position = p;
    return blocked;
}

fn respawn<T>(chunk: T&, state: State&) {
    state.position = float3 { 10.5, 1.0, 13.5 };
    // The spawn may have been edited. Find free space above its column.
    while collides(chunk, state.position) { state.position.y += 1.0; }
    state.velocity_y = 0.0;
    state.grounded = false;
    state.respawns++;
}

fn tick<T>(chunk: T&, state: State&, input: Input) {
    var forward = clamp(input.forward, -1.0, 1.0);
    var strafe = clamp(input.strafe, -1.0, 1.0);
    let magnitude = sqrt(forward * forward + strafe * strafe);
    if magnitude > 1.0 { forward /= magnitude; strafe /= magnitude; }
    let dx = (sin(state.yaw) * forward + cos(state.yaw) * strafe) * 4.2 * STEP;
    let dz = (-cos(state.yaw) * forward + sin(state.yaw) * strafe) * 4.2 * STEP;
    if input.jump && state.grounded {
        state.velocity_y = 7.0;
        state.jumps++;
    }
    state.velocity_y = max(state.velocity_y - 20.0 * STEP, -40.0);
    if dx != 0.0 { move_axis(chunk, state, 0, dx); }
    if dz != 0.0 { move_axis(chunk, state, 2, dz); }
    let falling = state.velocity_y < 0.0;
    let blocked = move_axis(chunk, state, 1, state.velocity_y * STEP);
    state.grounded = blocked && falling;
    if blocked { state.velocity_y = 0.0; }
    if state.position.y < world::lower_y(chunk) - 8.0 { respawn(chunk, state); }
    state.ticks++;
}
