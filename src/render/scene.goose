import core.core;
namespace scene;

struct Camera { view_projection: gfx::mat4 }

fn fixture() -> world::Chunk {
    var chunk = world::flat_fixture();
    for y in 1..5 { assert(world::set(chunk, 5, y, 5, 2)); }
    for y in 1..8 { assert(world::set(chunk, 10, y, 9, 2)); }
    return chunk;
}

fn run(offscreen: bool, empty: bool, frames: i64, output: u8[:]) {
    let opened = if offscreen { gfx::open_headless(640, 480) }
                 else { gfx::open("GooseCraft 0.2.0", 640, 480) };
    if !opened { write_stderr(str("graphics unavailable: ", gfx::error(), "\n")); exit(3); }
    defer gfx::close();
    var chunk = if empty { world::Chunk {} } else { fixture() };
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    mesh::build(chunk, vertices, indices);
    var vb = gfx::Buffer { 0 };
    var ib = gfx::Buffer { 0 };
    if indices.len > 0 {
        vb = gfx::vertex_buffer(bytes_of(vertices));
        ib = gfx::index_buffer(bytes_of(indices));
        if vb.id == 0 || ib.id == 0 { abort(str("GPU buffers: ", gfx::error())); }
    }
    let vs = embed_shader("vert", """
        layout(location = 0) in vec3 position;
        layout(location = 1) in vec4 color;
        layout(set = 1, binding = 0) uniform Camera { mat4 view_projection; };
        layout(location = 0) out vec4 face_color;
        void main() {
            face_color = color;
            gl_Position = view_projection * vec4(position, 1.0);
        }
        """);
    let fs = embed_shader("frag", """
        layout(location = 0) in vec4 face_color;
        layout(location = 0) out vec4 result;
        void main() { result = face_color; }
        """);
    var desc = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true };
    desc.formats[1] = gfx::VERTEX_UBYTE4_NORM;
    let pipeline = gfx::pipeline(vs, fs, desc);
    if pipeline.id == 0 { abort(str("GPU pipeline: ", gfx::error())); }
    var drawn: i64 = 0;
    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        let size = gfx::screen_size();
        let camera = Camera { view_projection: gfx::mul(
            gfx::perspective(0.8, size.x as f32 / size.y, 0.1, 128.0),
            gfx::look_at(float3 { 25.0, 23.0, 29.0 }, float3 { 8.0, 0.0, 8.0 }, float3 { 0.0, 1.0, 0.0 })) };
        gfx::begin_screen(float4 { 15.0 / 255.0, 23.0 / 255.0, 35.0 / 255.0, 1.0 });
        if indices.len > 0 {
            gfx::bind(pipeline);
            gfx::bind_vertex_buffer(vb);
            gfx::bind_index_buffer(ib, 4);
            gfx::uniforms(gfx::VERTEX, 0, camera);
            gfx::draw_indexed(indices.len);
        }
        gfx::end_pass();
        drawn++;
        if frames > 0 && drawn >= frames { break; }
    }
    gfx::flush();
    let size = gfx::screen_size();
    let pixels = gfx::read_pixels(gfx::screen());
    if pixels.len != size.x as i64 * size.y * 4 { abort("invalid screen readback size"); }
    var colored: i64 = 0;
    for p in 0..pixels.len / 4 {
        let at = p * 4;
        if abs(pixels[at] as i64 - 15) > 1 || abs(pixels[at + 1] as i64 - 23) > 1 ||
           abs(pixels[at + 2] as i64 - 35) > 1 { colored++; }
    }
    if output.len > 0 && !gfx::screenshot(output) {
        write_stderr(str("screenshot failed: ", gfx::error(), "\n")); exit(4);
    }
    gfx::check();
    print("{\"mode\":\"", if offscreen { "offscreen" } else { "window" },
        "\",\"driver\":\"", gfx::driver(), "\",\"frames\":", drawn,
        ",\"width\":", size.x, ",\"height\":", size.y,
        ",\"vertices\":", vertices.len, ",\"indices\":", indices.len,
        ",\"colored_pixels\":", colored, ",\"misuse_count\":", gfx::misuse_count(), "}");
}
