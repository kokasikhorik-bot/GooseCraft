import core.core;
namespace materials;

struct Camera { view_projection: gfx::mat4 }
struct Resources {
    pipeline: gfx::Pipeline = gfx::Pipeline { 0 },
    atlas: gfx::Texture = gfx::Texture { 0 },
    sampler: gfx::Sampler = gfx::Sampler { 0 },
}

fn create() -> Resources {
    let vs = embed_shader("vert", """
        layout(location = 0) in vec3 position;
        layout(location = 1) in vec4 color;
        layout(location = 2) in vec4 tile;
        layout(set = 1, binding = 0) uniform Camera { mat4 view_projection; };
        layout(location = 0) out vec4 face_light;
        layout(location = 1) out vec2 uv;
        layout(location = 2) flat out float tile_layer;
        void main() {
            int axis = int(round(tile.x * 255.0));
            uv = axis == 0 ? vec2(position.z, -position.y)
               : axis == 1 ? position.xz : vec2(position.x, -position.y);
            tile_layer = round(tile.y * 255.0);
            face_light = color;
            gl_Position = view_projection * vec4(position, 1.0);
        }
        """);
    let fs = embed_shader("frag", """
        layout(location = 0) in vec4 face_light;
        layout(location = 1) in vec2 uv;
        layout(location = 2) flat in float tile_layer;
        layout(set = 2, binding = 0) uniform sampler2DArray tiles;
        layout(location = 0) out vec4 result;
        void main() { result = texture(tiles, vec3(uv, tile_layer)) * face_light; }
        """);
    var desc = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true };
    desc.formats[1] = gfx::VERTEX_UBYTE4_NORM;
    desc.formats[2] = gfx::VERTEX_UBYTE4_NORM;
    var result = Resources { pipeline: gfx::pipeline(vs, fs, desc),
        atlas: gfx::texture_array(16, 16, 4, gfx::RGBA8, gfx::SAMPLED),
        sampler: gfx::sampler(gfx::NEAREST, gfx::REPEAT) };
    if result.pipeline.id == 0 || result.atlas.id == 0 || result.sampler.id == 0 {
        abort(str("texture resources: ", gfx::error()));
    }
    let pixels = textures::pixels();
    for layer in 4 {
        if !gfx::update_texture(result.atlas, gfx::Region { layer: layer as i32 }, pixels[layer * 1024..(layer + 1) * 1024]) {
            abort(str("tile upload: ", gfx::error()));
        }
    }
    return result;
}
fn bind(resources: Resources) {
    gfx::bind(resources.pipeline);
    gfx::bind_texture(gfx::FRAGMENT, 0, resources.atlas, resources.sampler);
}
fn release(resources: Resources) {
    if resources.pipeline.id != 0 { gfx::release(resources.pipeline); }
    if resources.atlas.id != 0 { gfx::release(resources.atlas); }
    if resources.sampler.id != 0 { gfx::release(resources.sampler); }
}
