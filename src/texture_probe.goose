// Automated GPU test executable; not included in the player distribution.
import gfx from "../.cache/upstream/goose_gfx";
import os;
import core.core;
import render.materials;

fn main() {
    let argv = args(); assert(argv.len == 2);
    assert(gfx::open_headless(640, 480)); defer gfx::close();
    let resources = materials::create(); defer materials::release(resources);
    let buffer = gfx::buffer(gfx::BUFFER_VERTEX, 4 * 20, []); defer gfx::release(buffer);
    let indices: u32[6] = [0, 1, 2, 0, 2, 3];
    let ib = gfx::index_buffer(bytes_of(indices)); defer gfx::release(ib);
    let corners: float2[4] = [float2 { -1.0, -1.0 }, float2 { 1.0, -1.0 }, float2 { 1.0, 1.0 }, float2 { -1.0, 1.0 }];
    let shift = float3 { -16.0, -16.0, -16.0 };
    for axis in 3 { for layer in 4 {
        var vertices: textures::Vertex[>..] = [];
        for c in corners {
            let p = if axis == 0 { float3 { 0.5, c.y, c.x } }
                    else if axis == 1 { float3 { c.x, 0.5, -c.y } } else { float3 { c.x, c.y, 0.5 } };
            vertices.push(textures::Vertex { p + shift, [255; 4], [axis as u8, layer as u8, 0, 0] });
        }
        let basis = if axis == 0 { gfx::mat4 {
            float4 { 0.0, 0.0, 1.0, 0.0 }, float4 { 0.0, 1.0, 0.0, 0.0 },
            float4 { 1.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 1.0 } } }
            else if axis == 1 { gfx::mat4 {
                float4 { 1.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 1.0, 0.0 },
                float4 { 0.0, -1.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 1.0 } } } else { gfx::mat4_identity };
        assert(gfx::frame() && gfx::update_buffer(buffer, bytes_of(vertices)));
        gfx::begin_screen(float4 { 0.0, 0.0, 0.0, 1.0 });
        materials::bind(resources); gfx::bind_vertex_buffer(buffer); gfx::bind_index_buffer(ib, 4);
        gfx::uniforms(gfx::VERTEX, 0, materials::Camera { gfx::mul(basis, gfx::translate(-shift)) });
        gfx::draw_indexed(6); gfx::end_pass(); gfx::flush();
        assert(gfx::screenshot(str(argv[1], "/tiles-", axis, "-", layer, ".png")));
    } }
    gfx::check(); assert(gfx::misuse_count() == 0);
    print("{\"frames\":12,\"misuse_count\":0,\"negative_coordinates\":true,\"texture_bytes\":4096}");
}
