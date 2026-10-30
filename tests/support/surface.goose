import core from "../../src/core";
import math;
namespace surface;

// Expand rectangles back into unit faces. Every occupied slot is a unique
// (voxel, outward orientation, RGBA), allowing an exact surface comparison
// even though greedy and reference use different triangles and vertex counts.
fn coverage<T>(chunk: T&, vertices: mesh::Vertex[:], indices: u32[:], output: u32[:]) -> i64 {
    assert(vertices.len % 4 == 0 && indices.len == vertices.len / 4 * 6);
    var covered: i64 = 0;
    for quad in vertices.len / 4 {
        let base = quad * 4;
        let at = quad * 6;
        let expected: u32[6] = [base as u32, (base + 1) as u32, (base + 2) as u32,
                                base as u32, (base + 2) as u32, (base + 3) as u32];
        for i in 6 { assert(indices[at + i] == expected[i]); }
        let a = vertices[base].position;
        let b = vertices[base + 1].position;
        let c = vertices[base + 2].position;
        let d = vertices[base + 3].position;
        let normal = normalize(cross(b - a, c - a));
        let other = normalize(cross(c - a, d - a));
        assert(normal == other && abs(normal.x) + abs(normal.y) + abs(normal.z) == 1.0);
        let axis: i64 = if normal.x != 0.0 { 0 } else if normal.y != 0.0 { 1 } else { 2 };
        let n: f32 = if axis == 0 { normal.x } else if axis == 1 { normal.y } else { normal.z };
        let face = axis * 2 + (if n > 0.0 { 0 } else { 1 });
        var lo = a;
        var hi = a;
        let color = vertices[base].color;
        for i in 4 {
            let vertex = vertices[base + i];
            assert(vertex.color == color && color[3] == 255);
            let p = vertex.position;
            assert(p.x == floor(p.x) && p.y == floor(p.y) && p.z == floor(p.z));
            assert(p.x >= 0.0 && p.x <= 16.0 && p.y >= 0.0 && p.y <= 16.0 && p.z >= 0.0 && p.z <= 16.0);
            lo = float3 { min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
            hi = float3 { max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z) };
        }
        let lower: f32[3] = [lo.x, lo.y, lo.z];
        let upper: f32[3] = [hi.x, hi.y, hi.z];
        let u_axis = (axis + 1) % 3;
        let v_axis = (axis + 2) % 3;
        assert(lower[axis] == upper[axis]);
        assert(upper[u_axis] > lower[u_axis] && upper[v_axis] > lower[v_axis]);
        let rgba = (color[0] as u32) | ((color[1] as u32) << 8) |
                   ((color[2] as u32) << 16) | ((color[3] as u32) << 24);
        for v in (lower[v_axis] as i64)..(upper[v_axis] as i64) {
            for u in (lower[u_axis] as i64)..(upper[u_axis] as i64) {
                // Build the face center independently of mesh::point().
                var center = float3 { u + 0.5, v + 0.5, lower[axis] };
                if axis == 0 { center = float3 { lower[axis], u + 0.5, v + 0.5 }; }
                if axis == 1 { center = float3 { v + 0.5, lower[axis], u + 0.5 }; }
                let inside = center - normal * 0.5;
                let outside = center + normal * 0.5;
                let x = floor(inside.x) as i64;
                let y = floor(inside.y) as i64;
                let z = floor(inside.z) as i64;
                assert(world::contains(x, y, z) && mesh::solid(chunk, x, y, z));
                assert(!mesh::solid(chunk, floor(outside.x) as i64, floor(outside.y) as i64, floor(outside.z) as i64));
                let slot = face * 4096 + world::index(x, y, z);
                assert(output[slot] == 0); // No overlapping rectangles.
                output[slot] = rgba;
                covered++;
            }
        }
    }
    return covered;
}
