// Conform greedy rectangle boundaries before GPU rasterization. No gfx import.
import .mesh;
import math;
namespace stitch;

fn slot(p: float3) -> i64 {
    (p.x as i64) + 17 * ((p.y as i64) + 17 * (p.z as i64))
}

fn boundary(p: float3) -> bool {
    p.x == 0.0 || p.x == 16.0 || p.y == 0.0 || p.y == 16.0 || p.z == 0.0 || p.z == 16.0
}

// Input is the quad list from mesh::build. Original corners stay in place.
// Extra edge points and one center are appended only for a split rectangle.
// Unit boundary segments also agree with a neighbor rebuilt independently.
fn apply(vertices: mesh::Vertex[>..]&, indices: u32[>..]&) -> i64 {
    assert(vertices.len % 4 == 0 && indices.len == vertices.len / 4 * 6);
    let original = vertices.len;
    var large = false;
    for q in original / 4 {
        let d = vertices[q * 4 + 2].position - vertices[q * 4].position;
        if abs(d.x) + abs(d.y) + abs(d.z) > 2.0 { large = true; break; }
    }
    if !large { return 0; }
    var corners: bool[4913] = [false; 4913];
    for i in original { corners[slot(vertices[i].position)] = true; }
    var ring: u32[64] = [0; 64]; // Max perimeter of a 16x16 rectangle.
    var split: i64 = 0;
    indices.clear();
    for q in original / 4 {
        let base = q * 4;
        let color = vertices[base].color;
        var count: i64 = 0;
        for edge in 4 {
            ring[count] = (base + edge) as u32; count++;
            let a = vertices[base + edge].position;
            let d = vertices[base + (edge + 1) % 4].position - a;
            let length = (abs(d.x) + abs(d.y) + abs(d.z)) as i64;
            // Divide an integral axis delta by its length: exactly -1/0/+1.
            let step = float3 { d.x / length, d.y / length, d.z / length };
            for at in 1..length {
                let p = a + step * (at as f32);
                if corners[slot(p)] || boundary(p) {
                    ring[count] = vertices.len as u32; count++;
                    vertices.push(mesh::Vertex { p, color });
                }
            }
        }
        if count == 4 {
            let b = base as u32;
            indices.append([b, b + 1, b + 2, b, b + 2, b + 3]);
        } else {
            let center = vertices.len as u32;
            vertices.push(mesh::Vertex { (vertices[base].position + vertices[base + 2].position) * 0.5, color });
            for i in count { indices.append([center, ring[i], ring[(i + 1) % count]]); }
            split++;
        }
    }
    return split;
}
