// Grid traversal and editing rules, independent of camera/rendering libraries.
import math;
import std;
import vec;
import .world;
import .player;
namespace interaction;

struct Hit {
    found: bool = false,
    cell: int3 = int3 { 0, 0, 0 },
    normal: int3 = int3 { 0, 0, 0 },
    distance: f32 = 0.0,
}

// Amanatides-Woo voxel traversal; distance is in world units, including when
// the caller supplies a non-unit direction. Exact ties choose X, then Y, Z.
fn raycast(chunk: world::Chunk&, origin: float3, direction: float3, reach: f32) -> Hit {
    let size = length(direction);
    if size < 0.000001 || reach < 0.0 { return Hit {}; }
    let d = direction / size;
    var cell = int3 { floor(origin.x) as i32, floor(origin.y) as i32, floor(origin.z) as i32 };
    let step = int3 { if d.x > 0.0 { 1 } else { -1 },
                     if d.y > 0.0 { 1 } else { -1 },
                     if d.z > 0.0 { 1 } else { -1 } };
    let delta = float3 { if abs(d.x) < 0.000001 { 1e30 } else { abs(1.0 / d.x) },
                        if abs(d.y) < 0.000001 { 1e30 } else { abs(1.0 / d.y) },
                        if abs(d.z) < 0.000001 { 1e30 } else { abs(1.0 / d.z) } };
    var next = float3 {
        if abs(d.x) < 0.000001 { 1e30 } else { (cell.x + (if d.x > 0.0 { 1 } else { 0 }) - origin.x) / d.x },
        if abs(d.y) < 0.000001 { 1e30 } else { (cell.y + (if d.y > 0.0 { 1 } else { 0 }) - origin.y) / d.y },
        if abs(d.z) < 0.000001 { 1e30 } else { (cell.z + (if d.z > 0.0 { 1 } else { 0 }) - origin.z) / d.z } };
    var normal = int3 { 0, 0, 0 };
    var distance: f32 = 0.0;
    for i in 128 {
        if world::contains(cell.x, cell.y, cell.z) && world::get(chunk, cell.x, cell.y, cell.z) != 0 {
            return Hit { found: true, cell: cell, normal: normal, distance: distance };
        }
        if next.x <= next.y && next.x <= next.z {
            distance = next.x; next.x += delta.x; cell.x += step.x;
            normal = int3 { -step.x, 0, 0 };
        } else if next.y <= next.z {
            distance = next.y; next.y += delta.y; cell.y += step.y;
            normal = int3 { 0, -step.y, 0 };
        } else {
            distance = next.z; next.z += delta.z; cell.z += step.z;
            normal = int3 { 0, 0, -step.z };
        }
        if distance > reach { break; }
    }
    return Hit {};
}

fn remove(chunk: world::Chunk&, hit: Hit) -> bool {
    if !hit.found || !world::contains(hit.cell.x, hit.cell.y, hit.cell.z) { return false; }
    if world::get(chunk, hit.cell.x, hit.cell.y, hit.cell.z) == 0 { return false; }
    return world::set(chunk, hit.cell.x, hit.cell.y, hit.cell.z, 0);
}

fn place(chunk: world::Chunk&, hit: Hit, position: float3, material: u8) -> bool {
    if !hit.found || (material != 1 && material != 2) { return false; }
    if abs(hit.normal.x) + abs(hit.normal.y) + abs(hit.normal.z) != 1 { return false; }
    let cell = hit.cell + hit.normal;
    if !world::contains(cell.x, cell.y, cell.z) { return false; }
    if world::get(chunk, cell.x, cell.y, cell.z) != 0 { return false; }
    if player::overlaps_cell(position, cell.x, cell.y, cell.z) { return false; }
    return world::set(chunk, cell.x, cell.y, cell.z, material);
}
