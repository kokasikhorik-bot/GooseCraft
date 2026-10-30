// CPU geometry only: the headless tests do not import gfx or SDL.
import vec;
import .world;
namespace mesh;

struct Vertex { position: float3, color: u8[4] }

fn solid<T>(chunk: T&, x: i64, y: i64, z: i64) -> bool {
    return world::sample(chunk, x, y, z) != 0;
}

// Outward counterclockwise corners: +X, -X, +Y, -Y, +Z, -Z.
fn build_reference<T>(chunk: T&, vertices: Vertex[>..]&, indices: u32[>..]&, neutral: bool = false) {
    assert(vertices.len == 0 && indices.len == 0);
    let corners: u8[3][4][6] = [
        [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]],
        [[0, 0, 1], [0, 1, 1], [0, 1, 0], [0, 0, 0]],
        [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]],
        [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]],
        [[1, 0, 1], [1, 1, 1], [0, 1, 1], [0, 0, 1]],
        [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]],
    ];
    let steps: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0],
                            [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    let light: f32[6] = [0.78, 0.58, 1.0, 0.42, 0.7, 0.62];
    for y in 16 {
        for z in 16 {
            for x in 16 {
                let id = world::get(chunk, x, y, z);
                if id == 0 { continue; }
                let tint: u8[3] = if neutral { [255; 3] } else if id == 1 { [72, 165, 102] } else { [239, 174, 67] };
                for face in 6 {
                    let delta = steps[face];
                    if solid(chunk, x + delta[0], y + delta[1], z + delta[2]) { continue; }
                    let base = vertices.len as u32;
                    let color: u8[4] = [(tint[0] * light[face]) as! u8,
                                        (tint[1] * light[face]) as! u8,
                                        (tint[2] * light[face]) as! u8, 255];
                    for c in corners[face] {
                        vertices.push(Vertex { position: float3 { x + c[0],
                            y + c[1], z + c[2] }, color: color });
                    }
                    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
                }
            }
        }
    }
}

// Axis-local coordinates: cyclic U/V preserve the outward winding below.
fn point(axis: i64, n: f32, u: f32, v: f32) -> float3 {
    if axis == 0 { return float3 { n, u, v }; }
    if axis == 1 { return float3 { v, n, u }; }
    return float3 { u, v, n };
}

// Greedy rectangles join only coplanar, equally oriented faces of the same
// material. A single visibility pass fills 96 masks; empty planes are skipped.
// Scratch storage is bounded (24,576 mask bytes + 96 flags), without a heap.
fn build<T>(chunk: T&, vertices: Vertex[>..]&, indices: u32[>..]&, neutral: bool = false) {
    assert(vertices.len == 0 && indices.len == 0);
    var masks: u8[24576] = [0; 24576];
    var used: bool[96] = [false; 96];
    let steps: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0],
                            [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    for y in 16 {
        for z in 16 {
            for x in 16 {
                let id = world::get(chunk, x, y, z);
                if id == 0 { continue; }
                let coordinates: i64[3] = [x, y, z];
                for face in 6 {
                    let step = steps[face];
                    if solid(chunk, x + step[0], y + step[1], z + step[2]) { continue; }
                    let axis = face / 2;
                    let plane = face * 16 + coordinates[axis];
                    let u = coordinates[(axis + 1) % 3];
                    let v = coordinates[(axis + 2) % 3];
                    masks[plane * 256 + v * 16 + u] = id;
                    used[plane] = true;
                }
            }
        }
    }
    let light: f32[6] = [0.78, 0.58, 1.0, 0.42, 0.7, 0.62];
    for face in 6 {
        let axis = face / 2;
        let positive = face % 2 == 0;
        let green_tint: u8[3] = if neutral { [255; 3] } else { [72, 165, 102] };
        let amber_tint: u8[3] = if neutral { [255; 3] } else { [239, 174, 67] };
        let green: u8[4] = [(green_tint[0] * light[face]) as! u8, (green_tint[1] * light[face]) as! u8,
                            (green_tint[2] * light[face]) as! u8, 255];
        let amber: u8[4] = [(amber_tint[0] * light[face]) as! u8, (amber_tint[1] * light[face]) as! u8,
                            (amber_tint[2] * light[face]) as! u8, 255];
        for slice in 16 {
            let plane = face * 16 + slice;
            if !used[plane] { continue; }
            let offset = plane * 256;
            for v in 16 {
                var u: i64 = 0;
                while u < 16 {
                    let id = masks[offset + v * 16 + u];
                    if id == 0 { u++; continue; }
                    var width: i64 = 1;
                    while u + width < 16 && masks[offset + v * 16 + u + width] == id { width++; }
                    var height: i64 = 1;
                    while v + height < 16 {
                        var same = true;
                        for col in width {
                            if masks[offset + (v + height) * 16 + u + col] != id { same = false; break; }
                        }
                        if !same { break; }
                        height++;
                    }
                    let color = if id == 1 { green } else { amber };
                    let n: f32 = slice + (if positive { 1 } else { 0 });
                    // Cyclic U/V has positive winding; reverse it on -faces.
                    let first_v = if positive { v } else { v + height };
                    let last_v = if positive { v + height } else { v };
                    let base = vertices.len as u32;
                    let a = Vertex { point(axis, n, u, first_v), color };
                    let b = Vertex { point(axis, n, u + width, first_v), color };
                    let c = Vertex { point(axis, n, u + width, last_v), color };
                    let d = Vertex { point(axis, n, u, last_v), color };
                    // Keep the reference diagonal too: changing a coplanar
                    // triangle's diagonal can change edge coverage after f32
                    // perspective projection even with the same voxel surface.
                    if axis == 0 {
                        vertices.push(a); vertices.push(b); vertices.push(c); vertices.push(d);
                    } else if positive {
                        vertices.push(b); vertices.push(c); vertices.push(d); vertices.push(a);
                    } else {
                        vertices.push(d); vertices.push(a); vertices.push(b); vertices.push(c);
                    }
                    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
                    for row in height {
                        for col in width { masks[offset + (v + row) * 16 + u + col] = 0; }
                    }
                    u += width;
                }
            }
        }
    }
}
