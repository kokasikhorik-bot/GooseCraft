import core from "../src/core";
import .support.surface;

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
    let old_count = surface::coverage(chunk, reference, reference_indices, old_coverage);
    let new_count = surface::coverage(chunk, greedy, greedy_indices, new_coverage);
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
