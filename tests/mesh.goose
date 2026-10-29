import core from "../src/core";

fn verify(chunk: world::Chunk&, expected_faces: i64) {
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    mesh::build(chunk, vertices, indices);
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

fn main() {
    var chunk = world::Chunk {};
    verify(chunk, 0);
    assert(world::set(chunk, 0, 0, 0, 1));
    verify(chunk, 6);
    assert(world::set(chunk, 1, 0, 0, 2));
    verify(chunk, 10);   // Shared face is absent on both blocks.
    var flat = world::flat_fixture();
    verify(flat, 576);   // Top/bottom and the four outer edges.
    var full = world::Chunk {};
    for y in 16 { for z in 16 { for x in 16 { assert(world::set(full, x, y, z, 1)); } } }
    verify(full, 1536);  // Only the outside of the full chunk.
    print("headless mesh: ok");
}
