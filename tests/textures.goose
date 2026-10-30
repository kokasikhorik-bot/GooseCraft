import os;
import core from "../src/core";
import .support.surface;
import .support.triangles;

fn verify<T>(source: T&, ao: bool) {
    var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
    if ao { occlusion::build(source, vertices, indices, true); }
    else { mesh::build(source, vertices, indices, true); }
    var textured: textures::Vertex[>..] = []; textures::convert(source, vertices, textured);
    assert(bytes_of(vertices).len == vertices.len * 16 && bytes_of(textured).len == textured.len * 20);
    for q in textured.len / 4 {
        let at = q * 4; let p = textured[at].position;
        let n = cross(textured[at + 1].position - p, textured[at + 2].position - p);
        let axis: i64 = if n.x != 0.0 { 0 } else if n.y != 0.0 { 1 } else { 2 };
        let positive = n.x + n.y + n.z > 0.0;
        var lo: f32[3] = [16.0; 3]; var hi: f32[3] = [0.0; 3];
        for i in 4 {
            let v = textured[at + i]; let xyz: f32[3] = [v.position.x, v.position.y, v.position.z];
            assert(v.tile == textured[at].tile && v.tile[0] == axis && v.tile[2] == 0 && v.tile[3] == 0);
            assert(v.position == vertices[at + i].position && v.color == vertices[at + i].color);
            assert(v.color[0] == v.color[1] && v.color[0] == v.color[2] && v.color[3] == 255);
            for k in 3 { lo[k] = min(lo[k], xyz[k]); hi[k] = max(hi[k], xyz[k]); }
            let uv = textures::uv(v.position, axis);
            if axis == 0 { assert(uv == float2 { v.position.z, -v.position.y }); }
            else if axis == 1 { assert(uv == float2 { v.position.x, v.position.z }); }
            else { assert(uv == float2 { v.position.x, -v.position.y }); }
        }
        let u = (axis + 1) % 3; let v = (axis + 2) % 3;
        for vv in (lo[v] as i64)..(hi[v] as i64) { for uu in (lo[u] as i64)..(hi[u] as i64) {
            var cell: i64[3] = [0; 3]; cell[axis] = lo[axis] as i64 - (if positive { 1 } else { 0 }); cell[u] = uu; cell[v] = vv;
            let id = world::get(source, cell[0], cell[1], cell[2]); assert(id == 1 || id == 2);
            let wanted: u8 = if id == 2 { 3 } else if axis == 1 { if positive { 0 } else { 2 } } else { 1 };
            assert(textured[at].tile[1] == wanted); // Every unit cell, not only the first.
        } }
    }
    // The generic stitcher must preserve all original vertices and metadata.
    stitch::apply(vertices, indices); let expected = copy(indices);
    var stitched: u32[>..] = [];
    for q in textured.len / 4 { let b = (q * 4) as u32; stitched.append([b, b + 1, b + 2, b, b + 2, b + 3]); }
    let original = copy(textured); stitch::apply(textured, stitched);
    assert(stitched == expected && textured.len == vertices.len);
    var geometry: mesh::Vertex[>..] = [];
    for i in textured.len {
        assert(textured[i].position == vertices[i].position && textured[i].color == vertices[i].color);
        if i < original.len { assert(textured[i] == original[i]); }
        geometry.push(mesh::Vertex { textured[i].position, textured[i].color });
    }
    for t in stitched.len / 3 {
        let a = textured[stitched[t * 3]]; let b = textured[stitched[t * 3 + 1]]; let c = textured[stitched[t * 3 + 2]];
        assert(a.tile == b.tile && a.tile == c.tile);
        // Projection is affine even on edge splits and half-grid fan centers.
        let middle = (a.position + b.position + c.position) * (1.0 / 3.0);
        let projected = textures::uv(middle, a.tile[0]);
        let average = (textures::uv(a.position, a.tile[0]) + textures::uv(b.position, a.tile[0]) + textures::uv(c.position, a.tile[0])) * (1.0 / 3.0);
        assert(length(projected - average) < 0.00001);
    }
    var reference: mesh::Vertex[>..] = []; var reference_indices: u32[>..] = [];
    mesh::build_reference(source, reference, reference_indices);
    var covered: u32[24576] = [0; 24576]; surface::coverage(source, reference, reference_indices, covered);
    assert(triangles::coverage(geometry, stitched, covered, true) && triangles::no_t_junctions(geometry, stitched));
}

fn main() {
    let pixels = textures::pixels();
    for layer in 4 { for y in 16 { for x in 16 {
        let p = textures::pixel(layer, x, y); assert(p[3] == 255);
        for c in 4 { assert(pixels[((layer * 16 + y) * 16 + x) * 4 + c] == p[c]); }
    } } }
    for axis in 3 {
        let a = textures::uv(float3 { -17.25, -16.5, -0.75 }, axis);
        let b = textures::uv(float3 { -1.25, -0.5, 15.25 }, axis);
        assert(a.x - floor(a.x) == b.x - floor(b.x) && a.y - floor(a.y) == b.y - floor(b.y));
    }
    var flat = world::flat_fixture(); verify(flat, false); verify(flat, true);
    var demo = world::demo_fixture(); verify(demo, false); verify(demo, true);
    var map = world::generate_tall(12345, 1);
    for cy in [-1, 0, 1, 2] {
        var halo = world::neighborhood(map, world::section_slot(map, -1, cy, -1)); verify(halo, false); verify(halo, true);
    }
    let argv = args(); assert(argv.len == 2 && write_file_atomic(argv[1], pixels));
    print("headless textures: ok");
}
