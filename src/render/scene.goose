import core.core;
import .hud;
import .replay;
import .chunks;
namespace scene;

struct Camera { view_projection: gfx::mat4 }

struct Options {
    offscreen: bool = false, empty: bool = false, preview: bool = false,
    replay_input: bool = false, seam_replay: bool = false, reference: bool = false,
    single: bool = false, persistent: bool = false, away: bool = false, frames: i64 = -1,
    demo: bool = false, terrain_replay: bool = false, seed_explicit: bool = false, seed: u32 = terrain::DEFAULT_SEED,
    raw: bool = false, preview_view: i64 = 0,
    radius: i64 = 4, radius_explicit: bool = false,
    far_replay: bool = false,
    profile_warmup: i64 = 30, profile_path: const u8[:] = "",
    output: const u8[:] = "", world_path: const u8[:] = "",
}

fn run(options: Options) {
    let profiled = options.profile_path.len > 0;
    let startup_begin = if profiled { clock_ns() } else { 0 };
    if profiled && (file_exists(options.profile_path) || is_dir(options.profile_path)) {
        write_stderr("profile path already exists; original file was not changed\n"); exit(7);
    }
    var profiles: profiling::Log[>..] = [];
    if profiled { profiles.push(profiling::Log { warmup: options.profile_warmup }); }
    let offscreen = options.offscreen;
    let preview = options.preview;
    let replay_input = options.replay_input;
    let reference = options.reference;
    let frames = options.frames;
    let output = options.output;
    var chunk = world::Map {};
    var loaded = false;
    if options.persistent {
        if is_dir(options.world_path) { write_stderr("world path is a directory\n"); exit(5); }
        if file_exists(options.world_path) {
            if options.seed_explicit {
                write_stderr("--seed requires a new world path; existing save was not changed\n"); exit(2);
            }
            if !storage::load(options.world_path, chunk) || (options.single && chunk.radius != 0) {
                write_stderr("invalid or unreadable world file; original file was not changed\n"); exit(5);
            }
            if options.radius_explicit && chunk.radius != options.radius {
                write_stderr("existing world radius differs; use a new world path to change size\n"); exit(2);
            }
            loaded = true;
        }
    }
    if !loaded {
        chunk = if options.demo || options.empty { world::region(options.single, options.empty, options.radius) }
                else { terrain::generate(options.seed, options.single, options.radius) };
    }
    let generated = !loaded && !options.demo && !options.empty;
    let seed_report: i64 = if generated { options.seed } else { -1 };
    var saved_revision: i64 = if loaded { chunk.revision } else { -1 };
    var save_status: i64 = if !options.persistent { 0 } else if loaded { 2 } else { 1 };
    var save_writes: i64 = 0;
    let opened = if offscreen { gfx::open_headless(640, 480) }
                 else { gfx::open("GooseCraft 0.8.0", 640, 480) };
    if !opened { write_stderr(str("graphics unavailable: ", gfx::error(), "\n")); exit(3); }
    defer gfx::close();
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    var buffers: chunks::Cache[>..] = [];
    buffers.resize(chunk.chunks.len, chunks::Cache {});
    // Complete startup meshes once; subsequent frames have a two-chunk budget.
    let initial_mesh_begin = if profiled { clock_ns() } else { 0 };
    var remeshes = chunks::rebuild_dirty(chunk, buffers, vertices, indices, chunk.chunks.len, reference, options.raw);
    let initial_mesh_ns = if profiled { clock_ns() - initial_mesh_begin } else { 0 };
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
    var hud_key = hud::Key {};
    var outline_cell = int3 { -1, -1, -1 };
    var hud_uploads: i64 = 0;
    var hud_uploaded_bytes: i64 = 0;
    var outline_uploads: i64 = 0;
    var outline_uploaded_bytes: i64 = 0;
    var state = player::State {};
    if options.seam_replay { state.position.x = 15.5; }
    if options.far_replay { state.position.x = 31.5; }
    while player::collides(chunk, state.position) { state.position.y += 1.0; }
    var active = true;
    var was_focused = true;
    var accumulator: f32 = 0.0;
    var jump_pending = false;
    var selected: u8 = 1;
    var broken: i64 = 0;
    var placed: i64 = 0;
    var paused_frames: i64 = 0;
    var focus_losses: i64 = 0;
    var resumes: i64 = 0;
    var walked: f32 = 0.0;
    var max_y: f32 = state.position.y;
    var max_x: f32 = state.position.x;
    var drawn_chunks: i64 = 0;
    var culled_chunks: i64 = 0;
    var drawn_vertices: i64 = 0;
    var drawn: i64 = 0;
    var last_upload_total: i64 = if profiled { chunks::stats(buffers).uploaded_bytes } else { 0 };
    var collector_ns_total: i64 = 0;
    let loop_begin = if profiled { clock_ns() } else { 0 };
    let startup_ns = if profiled { loop_begin - startup_begin } else { 0 };
    while true {
        if replay_input {
            if options.terrain_replay { replay::terrain_input(drawn); }
            else { replay::inject(drawn, options.seam_replay); }
        }
        let t0 = if profiled { clock_ns() } else { 0 };
        if !gfx::frame() { break; }
        let t1 = if profiled { clock_ns() } else { 0 };
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
                    max_x = max(max_x, state.position.x);
                    accumulator -= player::STEP;
                }
                hit = interaction::raycast(chunk, player::eye(state), player::direction(state), 6.0);
                var dirty = false;
                if !resumed && gfx::mouse_pressed(gfx::MOUSE_LEFT) && interaction::remove(chunk, hit) {
                    broken++; dirty = true;
                } else if gfx::mouse_pressed(gfx::MOUSE_RIGHT) && interaction::place(chunk, hit, state.position, selected) {
                    placed++; dirty = true;
                }
                if dirty && options.persistent { save_status = 1; }
            }
            hit = interaction::raycast(chunk, player::eye(state), player::direction(state), 6.0);
            assert(!player::collides(chunk, state.position));
        }
        let t2 = if profiled { clock_ns() } else { 0 };
        let rebuilt = chunks::rebuild_dirty(chunk, buffers, vertices, indices, 2, reference, options.raw);
        remeshes += rebuilt;
        let t3 = if profiled { clock_ns() } else { 0 };
        var save_calls: i64 = 0;
        if options.persistent && gfx::key_pressed("F5") {
            save_calls = 1;
            if storage::save(options.world_path, chunk) {
                saved_revision = chunk.revision; save_status = 2; save_writes++;
            } else { save_status = 3; write_stderr("world save failed; previous file retained\n"); }
        }
        let t4 = if profiled { clock_ns() } else { 0 };
        let size = gfx::screen_size();
        let overview_scale: f32 = (2 * chunk.radius + 1) / 3.0;
        var eye = if options.away { float3 { 80.0, 40.0, 80.0 } } else if preview {
            if chunk.radius == 0 { float3 { 25.0, 23.0, 29.0 } }
            else { float3 { 8.0 + 44.0 * overview_scale, 43.0 * overview_scale, 8.0 + 47.0 * overview_scale } }
        } else { player::eye(state) };
        if preview && !options.away {
            if options.preview_view % 2 == 1 { eye.x = 16.0 - eye.x; }
            if options.preview_view >= 2 { eye.z = 16.0 - eye.z; }
        }
        let target = if options.away { float3 { 96.0, 40.0, 96.0 } }
                     else if preview { float3 { 8.0, 0.0, 8.0 } } else { eye + player::direction(state) };
        let camera = Camera { view_projection: gfx::mul(
            gfx::perspective(if preview { 0.8 } else { 1.05 }, size.x as f32 / size.y, 0.05, max(192.0, 64.0 * (2 * chunk.radius + 1)) as! f32),
            gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })) };
        if !preview {
            let key = hud::Key { size, active, selected, hit.found, hit.cell, broken, placed, save_status };
            if reference || key != hud_key {
                hud::build(hud_vertices, size, active, selected, hit, broken, placed, save_status);
                let bytes = bytes_of(hud_vertices);
                if !gfx::update_buffer(hud_buffer, bytes) { abort(str("HUD upload: ", gfx::error())); }
                hud_uploads++; hud_uploaded_bytes += bytes.len; hud_key = key;
            }
            if hit.found && (reference || hit.cell != outline_cell) {
                hud::outline(outline_vertices, hit);
                if !gfx::update_buffer(outline_buffer, bytes_of(outline_vertices)) {
                    abort(str("outline upload: ", gfx::error()));
                }
                outline_uploads++; outline_cell = hit.cell;
                outline_uploaded_bytes += bytes_of(outline_vertices).len;
            }
        }
        gfx::begin_screen(float4 { 15.0 / 255.0, 23.0 / 255.0, 35.0 / 255.0, 1.0 });
        drawn_chunks = 0; culled_chunks = 0; drawn_vertices = 0;
        let rows: float4[4] = [gfx::row(camera.view_projection, 0), gfx::row(camera.view_projection, 1),
                                gfx::row(camera.view_projection, 2), gfx::row(camera.view_projection, 3)];
        for at in chunk.chunks.len {
            if !world::active(chunk, at) || buffers[at].indices == 0 { continue; }
            let origin = chunks::origin(chunk, at);
            if !reference && !visibility::intersects(rows, origin, origin + float3 { 16.0, 16.0, 16.0 }) {
                culled_chunks++; continue;
            }
            gfx::bind(pipeline);
            gfx::bind_vertex_buffer(buffers[at].vertex);
            gfx::bind_index_buffer(buffers[at].index, 4);
            gfx::uniforms(gfx::VERTEX, 0, Camera { gfx::mul(camera.view_projection, gfx::translate(origin)) });
            gfx::draw_indexed(buffers[at].indices);
            drawn_chunks++; drawn_vertices += buffers[at].vertices;
        }
        if !preview {
            if hit.found {
                gfx::bind(outline_pipeline); gfx::bind_vertex_buffer(outline_buffer);
                gfx::uniforms(gfx::VERTEX, 0, camera); gfx::draw(outline_vertices.len);
            }
            gfx::bind(hud_pipeline); gfx::bind_vertex_buffer(hud_buffer);
            gfx::uniforms(gfx::VERTEX, 0, Camera { gfx::mat4_identity }); gfx::draw(hud_vertices.len);
        }
        gfx::end_pass();
        if profiled {
            let t5 = clock_ns();
            let total_uploads = chunks::stats(buffers).uploaded_bytes + hud_uploaded_bytes + outline_uploaded_bytes;
            let draws = drawn_chunks + (if preview { 0 } else { 1 + (if hit.found { 1 } else { 0 }) });
            assert(profiling::record(profiles[0], profiling::Sample {
                frame: drawn, wall_ns: t5 - t0, pump_ns: t1 - t0, game_ns: t2 - t1,
                mesh_ns: t3 - t2, save_ns: t4 - t3, submit_ns: t5 - t4,
                rebuilt: rebuilt, draw_calls: draws, uploaded_bytes: total_uploads - last_upload_total,
                paused: if active { 0 } else { 1 }, save_calls: save_calls,
            }));
            last_upload_total = total_uploads;
            collector_ns_total += clock_ns() - t5;
        }
        drawn++;
        if frames > 0 && drawn >= frames { break; }
    }
    let tail_begin = if profiled { clock_ns() } else { 0 };
    let loop_session_ns = if profiled { tail_begin - loop_begin } else { 0 };
    gfx::flush();
    let tail_flush_ns = if profiled { clock_ns() - tail_begin } else { 0 };
    let size = gfx::screen_size();
    var colored: i64 = -1; // Not measured unless a screenshot was requested.
    let readback_begin = if profiled { clock_ns() } else { 0 };
    if output.len > 0 {
        let pixels = gfx::read_pixels(gfx::screen());
        if pixels.len != size.x as i64 * size.y * 4 { abort("invalid screen readback size"); }
        colored = 0;
        for p in 0..pixels.len / 4 {
            let at = p * 4;
            if abs(pixels[at] as i64 - 15) > 1 || abs(pixels[at + 1] as i64 - 23) > 1 ||
               abs(pixels[at + 2] as i64 - 35) > 1 { colored++; }
        }
        if !gfx::screenshot(output) {
            write_stderr(str("screenshot failed: ", gfx::error(), "\n")); exit(4);
        }
    }
    let readback_ns = if profiled && output.len > 0 { clock_ns() - readback_begin } else { 0 };
    gfx::check();
    let exit_save_begin = if profiled { clock_ns() } else { 0 };
    if options.persistent && saved_revision != chunk.revision {
        if !storage::save(options.world_path, chunk) {
            write_stderr("world save failed on exit; previous file retained\n"); exit(6);
        }
        saved_revision = chunk.revision; save_writes++;
    }
    let exit_save_ns = if profiled { clock_ns() - exit_save_begin } else { 0 };
    let totals = chunks::stats(buffers);
    if profiled {
        let driver = gfx::driver();
        let context = profiling::Context { driver: driver, offscreen: offscreen, replay: replay_input,
            reference: reference, raw: options.raw, startup_ns: startup_ns, initial_mesh_ns: initial_mesh_ns,
            tail_flush_ns: tail_flush_ns, exit_readback_ns: readback_ns, exit_save_ns: exit_save_ns,
            loop_session_ns: loop_session_ns, collector_ns_total: collector_ns_total,
            readback: output.len > 0, world_block_capacity_bytes: bytes_of(chunk.chunks).len,
            active_world_block_bytes: world::count(chunk) * 4096,
            mesh_bytes: totals.vertices * 16 + totals.indices * 4, mesh_capacity_bytes: totals.capacity,
            mesh_buffer_creations: totals.allocations, overlay_buffer_capacity_bytes: 512 * 1024 + 24 * 16,
            overlay_buffer_creations: 2,
            world_radius: chunk.radius, world_chunks: world::count(chunk), world_format: storage::version(chunk),
        };
        if !profiling::save(options.profile_path, profiles[0], context) {
            write_stderr("profile export failed; existing files retained\n"); exit(7);
        }
    }
    let rendering_report = str("{\"mode\":\"", if offscreen { "offscreen" } else { "window" },
        "\",\"driver\":\"", gfx::driver(), "\",\"frames\":", drawn,
        ",\"width\":", size.x, ",\"height\":", size.y,
        ",\"vertices\":", totals.vertices, ",\"indices\":", totals.indices,
        ",\"colored_pixels\":", colored, ",\"misuse_count\":", gfx::misuse_count(),
        ",\"readback_performed\":", output.len > 0,
        ",\"reference_renderer\":", reference,
        ",\"mesh_bytes\":", totals.vertices * 16 + totals.indices * 4,
        ",\"mesh_capacity_bytes\":", totals.capacity,
        ",\"mesh_allocations\":", totals.allocations, ",\"mesh_uploaded_bytes\":", totals.uploaded_bytes,
        ",\"mesh_patches\":", totals.patches, ",\"split_patches\":", totals.split_patches,
        ",\"raw_greedy\":", options.raw,
        ",\"hud_uploads\":", hud_uploads, ",\"hud_uploaded_bytes\":", hud_uploaded_bytes,
        ",\"outline_uploads\":", outline_uploads,
        ",\"terrain_generated\":", generated,
        ",\"terrain_seed\":", seed_report, ",\"terrain_generator\":", if generated { 1 } else { 0 });
    let gameplay_report = str(",\"interactive\":", !preview, ",\"replay\":", replay_input,
        ",\"ticks\":", state.ticks, ",\"breaks\":", broken, ",\"places\":", placed,
        ",\"remeshes\":", remeshes, ",\"solid_blocks\":", world::solid_count(chunk),
        ",\"jumps\":", state.jumps, ",\"respawns\":", state.respawns,
        ",\"paused_frames\":", paused_frames, ",\"focus_losses\":", focus_losses,
        ",\"resumes\":", resumes, ",\"walked\":", walked, ",\"max_y\":", max_y,
        ",\"player_x\":", state.position.x, ",\"player_y\":", state.position.y,
        ",\"player_z\":", state.position.z, ",\"max_x\":", max_x,
        ",\"chunks\":", world::count(chunk),
        ",\"drawn_chunks\":", drawn_chunks, ",\"culled_chunks\":", culled_chunks,
        ",\"drawn_vertices\":", drawn_vertices, ",\"dirty_remaining\":", world::pending(chunk),
        ",\"revision\":", chunk.revision, ",\"save_enabled\":", options.persistent,
        ",\"loaded\":", loaded, ",\"save_writes\":", save_writes,
        ",\"world_radius\":", chunk.radius, ",\"world_format\":", storage::version(chunk), ",\"chunk_rebuilds\":[");
    var rebuild_report: u8[>..] = [];
    for at in buffers.len {
        if at > 0 { rebuild_report.push(','); }
        rebuild_report.append(str(buffers[at].rebuilds));
    }
    rebuild_report.append("]}");
    print(rendering_report, gameplay_report, rebuild_report);
}
