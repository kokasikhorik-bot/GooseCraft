import core from "../src/core";
import math;

fn verify(chunk: world::Chunk&, expected_faces: i64) {
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    mesh::build_reference(chunk, vertices, indices);
    assert(vertices.len == expected_faces * 4);
    assert(indices.len == expected_faces * 6);
    for index in indices { assert(index < vertices.len); }
    for vertex in vertices {
        assert(vertex.position.x >= 0.0 && vertex.position.x <= 16.0);
        assert(vertex.position.y >= 0.0 && vertex.position.y <= 16.0);
        assert(vertex.position.z >= 0.0 && vertex.position.z <= 16.0);
        assert(vertex.color[3] == 255);
    }
    // Both triangles must face away from the block, not be degenerate.
    for triangle in 0..indices.len / 3 {
        let first = triangle * 3;
        let a = vertices[indices[first]].position;
        let b = vertices[indices[first + 1]].position;
        let c = vertices[indices[first + 2]].position;
        let normal = cross(b - a, c - a);
        assert(dot(normal, normal) == 1.0);
        let inside = (a + b + c) * float3 { 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0 } - normal * float3 { 0.5, 0.5, 0.5 };
        assert(inside.x >= 0.0 && inside.x < 16.0 && inside.y >= 0.0 && inside.y < 16.0 &&
               inside.z >= 0.0 && inside.z < 16.0);
        assert(mesh::solid(chunk, inside.x as! i64, inside.y as! i64, inside.z as! i64));
    }
}

// Expand rectangles back into unit faces. Every occupied slot is a unique
// (voxel, outward orientation, RGBA), allowing an exact surface comparison
// even though greedy and reference use different triangles and vertex counts.
fn coverage(chunk: world::Chunk&, vertices: mesh::Vertex[:], indices: u32[:], output: u32[:]) -> i64 {
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

fn equivalent(chunk: world::Chunk&, expected_quads: i64 = -1) {
    var reference: mesh::Vertex[>..] = [];
    var reference_indices: u32[>..] = [];
    var greedy: mesh::Vertex[>..] = [];
    var greedy_indices: u32[>..] = [];
    mesh::build_reference(chunk, reference, reference_indices);
    mesh::build(chunk, greedy, greedy_indices);
    assert(greedy.len <= reference.len);
    if expected_quads >= 0 { assert(greedy.len == expected_quads * 4); }
    var old_coverage: u32[24576] = [0; 24576];
    var new_coverage: u32[24576] = [0; 24576];
    let old_count = coverage(chunk, reference, reference_indices, old_coverage);
    let new_count = coverage(chunk, greedy, greedy_indices, new_coverage);
    assert(old_count == new_count && old_coverage == new_coverage);
}

fn main() {
    var chunk = world::Chunk {};
    verify(chunk, 0);
    equivalent(chunk, 0);
    assert(world::set(chunk, 0, 0, 0, 1));
    verify(chunk, 6);
    equivalent(chunk, 6);
    assert(world::set(chunk, 1, 0, 0, 2));
    verify(chunk, 10);   // Shared face is absent on both blocks.
    equivalent(chunk, 10); // Different materials must stay separate.
    world::set(chunk, 1, 0, 0, 1);
    equivalent(chunk, 6); // The same surface with matching materials merges.
    var flat = world::flat_fixture();
    verify(flat, 576);   // Top/bottom and the four outer edges.
    equivalent(flat, 6);
    world::set(flat, 8, 1, 8, 2);
    equivalent(flat);
    world::set(flat, 7, 0, 8, 0);
    equivalent(flat);
    var full = world::Chunk {};
    for y in 16 { for z in 16 { for x in 16 { assert(world::set(full, x, y, z, 1)); } } }
    verify(full, 1536);  // Only the outside of the full chunk.
    equivalent(full, 6);
    for seed in 8 {
        var noisy = world::Chunk {};
        for y in 16 { for z in 16 { for x in 16 {
            if (x * 1597 + y * 241 + z * 3571 + seed * 101) % 17 < 8 {
                world::set(noisy, x, y, z, (1 + (x + y + seed) % 2) as u8);
            }
        } } }
        equivalent(noisy);
    }
    var checker = world::Chunk {};
    for y in 16 { for z in 16 { for x in 16 {
        if (x + y + z) % 2 == 0 { world::set(checker, x, y, z, 1); }
    } } }
    equivalent(checker, 12288); // Worst case: no coplanar adjacent faces.
    print("headless mesh: ok");
}
