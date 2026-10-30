import core.core;
import .hud;
import .replay;
namespace scene;

struct Camera { view_projection: gfx::mat4 }

fn fixture() -> world::Chunk {
    var chunk = world::flat_fixture();
    for y in 1..5 { assert(world::set(chunk, 5, y, 5, 2)); }
    for y in 1..8 { assert(world::set(chunk, 10, y, 9, 2)); }
    return chunk;
}

fn rebuild(chunk: world::Chunk&, vertices: mesh::Vertex[>..]&, indices: u32[>..]&,
           vb: gfx::Buffer&, ib: gfx::Buffer&) {
    if vb.id != 0 { gfx::release(vb); vb = gfx::Buffer { 0 }; }
    if ib.id != 0 { gfx::release(ib); ib = gfx::Buffer { 0 }; }
    vertices.clear(); indices.clear();
    mesh::build(chunk, vertices, indices);
    if indices.len > 0 {
        vb = gfx::vertex_buffer(bytes_of(vertices));
        ib = gfx::index_buffer(bytes_of(indices));
        if vb.id == 0 || ib.id == 0 { abort(str("GPU buffers: ", gfx::error())); }
    }
}

fn run(offscreen: bool, empty: bool, frames: i64, output: u8[:], preview: bool, replay_input: bool) {
    let opened = if offscreen { gfx::open_headless(640, 480) }
                 else { gfx::open("GooseCraft 0.3.0", 640, 480) };
    if !opened { write_stderr(str("graphics unavailable: ", gfx::error(), "\n")); exit(3); }
    defer gfx::close();
    var chunk = if empty { world::Chunk {} } else { fixture() };
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    var vb = gfx::Buffer { 0 };
    var ib = gfx::Buffer { 0 };
    rebuild(chunk, vertices, indices, vb, ib);
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
    desc.cull = gfx::CULL_NONE;
    desc.primitive = gfx::LINES;
    desc.depth_write = false;
    let outline_pipeline = gfx::pipeline(vs, fs, desc);
    desc.primitive = gfx::TRIANGLES;
    desc.depth_test = false;
    let hud_pipeline = gfx::pipeline(vs, fs, desc);
    if outline_pipeline.id == 0 || hud_pipeline.id == 0 { abort(str("overlay pipelines: ", gfx::error())); }
    let hud_buffer = gfx::buffer(gfx::BUFFER_VERTEX, 512 * 1024, []);
    let outline_buffer = gfx::buffer(gfx::BUFFER_VERTEX, 24 * 16, []);
    if hud_buffer.id == 0 || outline_buffer.id == 0 { abort(str("overlay buffers: ", gfx::error())); }
    var hud_vertices: mesh::Vertex[>..] = [];
    var outline_vertices: mesh::Vertex[>..] = [];
    var state = player::State {};
    var active = true;
    var was_focused = true;
    var accumulator: f32 = 0.0;
    var jump_pending = false;
    var selected: u8 = 1;
    var broken: i64 = 0;
    var placed: i64 = 0;
    var remeshes: i64 = 1;
    var paused_frames: i64 = 0;
    var focus_losses: i64 = 0;
    var resumes: i64 = 0;
    var walked: f32 = 0.0;
    var max_y: f32 = state.position.y;
    var drawn: i64 = 0;
    while true {
        if replay_input { replay::inject(drawn); }
        if !gfx::frame() { break; }
        if gfx::key_pressed("F10") || (preview && gfx::key_pressed("Escape")) { break; }
        var hit = interaction::Hit {};
        if !preview {
            let focused = gfx::focused();
            if !focused {
                if was_focused { focus_losses++; }
                active = false;
            }
            was_focused = focused;
            var resumed = false;
            if active && gfx::key_pressed("Escape") {
                active = false;
            } else if !active && focused && (gfx::key_pressed("Return") || gfx::mouse_pressed(gfx::MOUSE_LEFT)) {
                active = true; resumed = true; resumes++;
            }
            if !replay_input && active && (drawn == 0 || resumed) {
                if !gfx::set_mouse_relative(true) {
                    write_stderr(str("mouse capture unavailable: ", gfx::error(), "; use arrows to look\n"));
                }
            }
            if !active {
                if gfx::mouse_relative() { gfx::set_mouse_relative(false); }
                accumulator = 0.0; jump_pending = false; paused_frames++;
            } else {
                let elapsed: f32 = if replay_input { 1.0 / 60.0 } else { clamp(gfx::delta_time(), 0.0, 0.1) as! f32 };
                if drawn > 0 && !resumed && (replay_input || gfx::mouse_relative()) {
                    let mouse = gfx::mouse_delta();
                    player::look(state, mouse.x, mouse.y);
                }
                let turn_x: f32 = (if gfx::key_down("Right") { 1.0 } else { 0.0 }) -
                                   (if gfx::key_down("Left") { 1.0 } else { 0.0 });
                let turn_y: f32 = (if gfx::key_down("Down") { 1.0 } else { 0.0 }) -
                                   (if gfx::key_down("Up") { 1.0 } else { 0.0 });
                player::look(state, turn_x * elapsed * 720.0, turn_y * elapsed * 720.0);
                if gfx::key_pressed("R") {
                    player::respawn(chunk, state); state.yaw = 0.0; state.pitch = 0.0;
                }
                if gfx::key_pressed("1") { selected = 1; }
                if gfx::key_pressed("2") { selected = 2; }
                jump_pending = jump_pending || gfx::key_pressed("Space");
                var input = player::Input {
                    forward: (if gfx::key_down("W") { 1.0 } else { 0.0 }) - (if gfx::key_down("S") { 1.0 } else { 0.0 }),
                    strafe: (if gfx::key_down("D") { 1.0 } else { 0.0 }) - (if gfx::key_down("A") { 1.0 } else { 0.0 }),
                };
                accumulator += elapsed;
                while accumulator >= player::STEP {
                    input.jump = jump_pending; jump_pending = false;
                    let before = state.position;
                    player::tick(chunk, state, input);
                    walked += length(float2 { state.position.x - before.x, state.position.z - before.z });
                    max_y = max(max_y, state.position.y);
                    accumulator -= player::STEP;
                }
                hit = interaction::raycast(chunk, player::eye(state), player::direction(state), 6.0);
                var dirty = false;
                if !resumed && gfx::mouse_pressed(gfx::MOUSE_LEFT) && interaction::remove(chunk, hit) {
                    broken++; dirty = true;
                } else if gfx::mouse_pressed(gfx::MOUSE_RIGHT) && interaction::place(chunk, hit, state.position, selected) {
                    placed++; dirty = true;
                }
                if dirty { rebuild(chunk, vertices, indices, vb, ib); remeshes++; }
            }
            hit = interaction::raycast(chunk, player::eye(state), player::direction(state), 6.0);
            assert(!player::collides(chunk, state.position));
        }
        let size = gfx::screen_size();
        let eye = if preview { float3 { 25.0, 23.0, 29.0 } } else { player::eye(state) };
        let target = if preview { float3 { 8.0, 0.0, 8.0 } } else { eye + player::direction(state) };
        let camera = Camera { view_projection: gfx::mul(
            gfx::perspective(if preview { 0.8 } else { 1.05 }, size.x as f32 / size.y, 0.05, 128.0),
            gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })) };
        if !preview {
            hud::build(hud_vertices, size, active, selected, hit, broken, placed);
            hud::outline(outline_vertices, hit);
            if !gfx::update_buffer(hud_buffer, bytes_of(hud_vertices)) { abort(str("HUD upload: ", gfx::error())); }
            if outline_vertices.len > 0 && !gfx::update_buffer(outline_buffer, bytes_of(outline_vertices)) {
                abort(str("outline upload: ", gfx::error()));
            }
        }
        gfx::begin_screen(float4 { 15.0 / 255.0, 23.0 / 255.0, 35.0 / 255.0, 1.0 });
        if indices.len > 0 {
            gfx::bind(pipeline);
            gfx::bind_vertex_buffer(vb);
            gfx::bind_index_buffer(ib, 4);
            gfx::uniforms(gfx::VERTEX, 0, camera);
            gfx::draw_indexed(indices.len);
        }
        if !preview {
            if outline_vertices.len > 0 {
                gfx::bind(outline_pipeline); gfx::bind_vertex_buffer(outline_buffer);
                gfx::uniforms(gfx::VERTEX, 0, camera); gfx::draw(outline_vertices.len);
            }
            gfx::bind(hud_pipeline); gfx::bind_vertex_buffer(hud_buffer);
            gfx::uniforms(gfx::VERTEX, 0, Camera { gfx::mat4_identity }); gfx::draw(hud_vertices.len);
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
        ",\"colored_pixels\":", colored, ",\"misuse_count\":", gfx::misuse_count(),
        ",\"interactive\":", !preview, ",\"replay\":", replay_input,
        ",\"ticks\":", state.ticks, ",\"breaks\":", broken, ",\"places\":", placed,
        ",\"remeshes\":", remeshes, ",\"solid_blocks\":", world::solid_count(chunk),
        ",\"jumps\":", state.jumps, ",\"respawns\":", state.respawns,
        ",\"paused_frames\":", paused_frames, ",\"focus_losses\":", focus_losses,
        ",\"resumes\":", resumes, ",\"walked\":", walked, ",\"max_y\":", max_y,
        ",\"player_x\":", state.position.x, ",\"player_y\":", state.position.y,
        ",\"player_z\":", state.position.z, "}");
}
