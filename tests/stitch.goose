import core from "../src/core";
import .support.surface;
import .support.triangles;

fn verify<T>(chunk: T&, all_vertices: mesh::Vertex[>..]&, all_indices: u32[>..]&, origin: float3) {
    var reference: mesh::Vertex[>..] = [];
    var reference_indices: u32[>..] = [];
    mesh::build_reference(chunk, reference, reference_indices);
    var expected: u32[24576] = [0; 24576];
    surface::coverage(chunk, reference, reference_indices, expected);
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    mesh::build(chunk, vertices, indices);
    stitch::apply(vertices, indices);
    assert(triangles::coverage(vertices, indices, expected));
    assert(triangles::no_t_junctions(vertices, indices));
    let offset = all_vertices.len as u32;
    for vertex in vertices { all_vertices.push(mesh::Vertex { vertex.position + origin, vertex.color }); }
    for index in indices { all_indices.push(offset + index); }
    if indices.len > 0 {
        // The oracle must reject both a hole and an overlapping triangle.
        assert(!triangles::coverage(vertices, indices[..indices.len - 3], expected));
        let duplicate: u32[3] = [indices[0], indices[1], indices[2]];
        indices.append(duplicate);
        assert(!triangles::coverage(vertices, indices, expected));
    }
}

fn explicit_t() {
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    let positions: float3[8] = [float3 { 0.0, 1.0, 0.0 }, float3 { 2.0, 1.0, 0.0 },
        float3 { 2.0, 2.0, 0.0 }, float3 { 0.0, 2.0, 0.0 },
        float3 { 1.0, 0.0, 0.0 }, float3 { 2.0, 0.0, 0.0 },
        float3 { 2.0, 1.0, 0.0 }, float3 { 1.0, 1.0, 0.0 }];
    for p in positions { vertices.push(mesh::Vertex { p, [255; 4] }); }
    indices.append([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7]);
    assert(!triangles::no_t_junctions(vertices, indices));
    assert(stitch::apply(vertices, indices) > 0);
    assert(triangles::no_t_junctions(vertices, indices));
}

fn main() {
    assert(abs(triangles::area(triangles::P { 0.0, 0.0 }, triangles::P { 2.0, 0.0 },
                              triangles::P { 0.0, 2.0 }, 0, 0) - 1.0) < 0.0000001);
    explicit_t();
    let seeds: u32[4] = [0, 1, 12345, 4294967295];
    for seed in seeds {
        var map = terrain::generate(seed);
        var all_vertices: mesh::Vertex[>..] = [];
        var all_indices: u32[>..] = [];
        for at in 9 {
            var halo = world::neighborhood(map, at);
            verify(halo, all_vertices, all_indices, float3 { (at % 3) * 16, 0.0, (at / 3) * 16 });
        }
        assert(triangles::no_t_junctions(all_vertices, all_indices, 48));
    }
    for kind in 4 {
        var chunk = if kind == 0 { world::Chunk {} } else if kind == 1 { world::flat_fixture() } else { world::demo_fixture() };
        if kind == 3 {
            for y in 16 { for z in 16 { for x in 16 {
                world::set(chunk, x, y, z, if (x + y + z) % 2 == 0 { 1 } else { 0 });
            } } }
        }
        var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
        verify(chunk, vertices, indices, float3 { 0.0, 0.0, 0.0 });
    }
    print("headless stitch: ok");
}
