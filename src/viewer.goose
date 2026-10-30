// This local package is fetched and verified by tools/bootstrap.py --graphics.
import gfx from "../.cache/upstream/goose_gfx";
import os;
import std;
import render.scene;

fn main() {
    let argv = args();
    var options = scene::Options {};
    var no_save = false;
    var view_given = false;
    var warmup_given = false;
    var radius_given = false;
    var mesh_radius_given = false;
    var prefetch_delay_given = false;
    var page_delay_given = false;
    var output: u8[>..] = [];
    var world_path: u8[>..] = [];
    var profile_path: u8[>..] = [];
    var i: i64 = 1;
    while i < argv.len {
        let flag = argv[i];
        if flag == "--help" {
            print("GooseCraft 0.16.0: graphical scene and seeded terrain prototype");
            print("usage: goosecraft-client [--world FILE | --no-save] [--preview | --replay | --seam-replay]");
            print("       [--offscreen] [--empty] [--frames N] [--screenshot FILE]");
            print("       [--seed 0..4294967295 | --demo-world] [--terrain-replay]");
            print("       [--radius 1..4] (new regular games default to 4: 81 chunks, 144x144)");
            print("       [--profile NEW-FILE.json [--profile-warmup N]]");
            print("       [--mesh-radius 0..4] (regular games default to 2; 0 keeps the whole world)");
            print("       --paged-world DIR enables bounded CPU paging; mesh-radius must be 1 or 2. Existing GCW files stay separate.");
            print("       --deferred-respawn keeps drawing while R prepares pages (paged worker mode only).");
            print("Paged diagnostics require new .png screenshot files and .json profile files.");
            print("Paged preparation uses one Goose worker; --sync-paging selects the synchronous baseline.");
            print("Diagnostics: --prefetch-delay-ms 0..100 delays the worker; --page-delay-ms 0..20 delays each page preparation.");
            print("Diagnostics: --paging-replay walks farther before returning; default 680 frames.");
            print("Diagnostics: --retain-meshes keeps all GPU meshes but draws the same mesh-radius window; --stream-replay walks out and respawns.");
            print("WASD move; mouse/arrows look; Space jump; LMB break; RMB place; 1-9 slot; E creative inventory.");
            print("--tall-world FILE enables a separate GCW v4 world, Y -16..47; fully resident sections, no automatic migration.");
            print("Escape pauses; click/Enter resumes; R respawns; F5 saves; F10 quits and saves.");
            print("Default world: user profile / GooseCraft/worlds/default-v1.gcw. Player position is not saved.");
            print("New worlds: terrain v1, seed 12345. --seed applies only to a new world; existing saves are preserved.");
            print("Diagnostics: --single-chunk; --reference-renderer; --view-away (preview only); --seam-replay requires --demo-world.");
            print("Diagnostics: --raw-greedy disables edge stitching; --preview-view 0..3 changes overview direction.");
            print("--ambient-occlusion enables local corner shading; defaults off. More vertices and CPU work may be needed.");
            print("--textures enables original 16x16 repeating tiles; defaults off, works with --ambient-occlusion.");
            print("Replay, preview and single-chunk modes are temporary unless --world is explicit.");
            print("Preview/replay/demo default to radius 1. Existing saves keep their size; --radius must match when reopening.");
            print("Diagnostics: --far-replay starts at x=31.5 to cross the old boundary; requires radius >=2.");
            print("Profile: wall-clock CPU loop samples, last 1024 after 30 warmup frames; exported on clean exit. Use a new path.");
            return;
        } else if flag == "--offscreen" { options.offscreen = true; }
        else if flag == "--empty" { options.empty = true; }
        else if flag == "--preview" { options.preview = true; }
        else if flag == "--replay" || flag == "--seam-replay" || flag == "--terrain-replay" || flag == "--far-replay" || flag == "--stream-replay" || flag == "--paging-replay" || flag == "--inventory-replay" {
            if options.replay_input { abort_args(); }
            options.replay_input = true;
            options.seam_replay = flag == "--seam-replay";
            options.terrain_replay = flag == "--terrain-replay" || flag == "--far-replay" || flag == "--stream-replay" || flag == "--paging-replay";
            options.far_replay = flag == "--far-replay" || flag == "--stream-replay" || flag == "--paging-replay";
            options.stream_replay = flag == "--stream-replay";
            options.paging_replay = flag == "--paging-replay";
            options.inventory_replay = flag == "--inventory-replay";
        }
        else if flag == "--demo-world" { options.demo = true; }
        else if flag == "--seed" {
            if i + 1 >= argv.len || options.seed_explicit { abort_args(); }
            i++;
            let n, ok = parse_int(argv[i]);
            if !ok || n < 0 || n > 4294967295 { abort_args(); }
            options.seed = n as u32; options.seed_explicit = true;
        }
        else if flag == "--reference-renderer" { options.reference = true; }
        else if flag == "--ambient-occlusion" {
            if options.ambient_occlusion { abort_args(); }
            options.ambient_occlusion = true;
        }
        else if flag == "--textures" {
            if options.textures { abort_args(); }
            options.textures = true;
        }
        else if flag == "--radius" {
            if i + 1 >= argv.len || radius_given { abort_args(); }
            i++; let n, ok = parse_int(argv[i]);
            if !ok || n < 1 || n > 4 { abort_args(); }
            options.radius = n; radius_given = true; options.radius_explicit = true;
        }
        else if flag == "--raw-greedy" { options.raw = true; }
        else if flag == "--retain-meshes" { options.retain_meshes = true; }
        else if flag == "--sync-paging" { options.sync_paging = true; }
        else if flag == "--deferred-respawn" {
            if options.deferred_respawn { abort_args(); }
            options.deferred_respawn = true;
        }
        else if flag == "--prefetch-delay-ms" || flag == "--page-delay-ms" {
            let worker = flag == "--prefetch-delay-ms";
            if i + 1 >= argv.len || (worker && prefetch_delay_given) || (!worker && page_delay_given) { abort_args(); }
            i++; let n, ok = parse_int(argv[i]);
            if !ok || n < 0 || n > (if worker { 100 } else { 20 }) { abort_args(); }
            if worker { options.prefetch_delay = n; prefetch_delay_given = true; }
            else { options.page_delay = n; page_delay_given = true; }
        }
        else if flag == "--mesh-radius" {
            if i + 1 >= argv.len || mesh_radius_given { abort_args(); }
            i++; let n, ok = parse_int(argv[i]);
            if !ok || n < 0 || n > 4 { abort_args(); }
            options.mesh_radius = n; mesh_radius_given = true;
        }
        else if flag == "--preview-view" {
            if i + 1 >= argv.len { abort_args(); }
            i++; let n, ok = parse_int(argv[i]);
            if !ok || n < 0 || n > 3 { abort_args(); }
            options.preview_view = n; view_given = true;
        }
        else if flag == "--single-chunk" { options.single = true; }
        else if flag == "--view-away" { options.away = true; }
        else if flag == "--no-save" { no_save = true; }
        else if flag == "--world" || flag == "--paged-world" || flag == "--tall-world" {
            if i + 1 >= argv.len || world_path.len > 0 { abort_args(); }
            i++; world_path.append(argv[i]);
            if world_path.len == 0 { abort_args(); }
            options.paged = flag == "--paged-world";
            options.tall = flag == "--tall-world";
        }
        else if flag == "--profile" {
            if i + 1 >= argv.len || profile_path.len > 0 { abort_args(); }
            i++; profile_path.append(argv[i]);
            if profile_path.len == 0 { abort_args(); }
        }
        else if flag == "--profile-warmup" {
            if i + 1 >= argv.len || warmup_given { abort_args(); }
            i++; let n, ok = parse_int(argv[i]);
            if !ok || n < 0 || n > 10000 { abort_args(); }
            options.profile_warmup = n; warmup_given = true;
        }
        else if flag == "--frames" {
            if i + 1 >= argv.len { abort_args(); }
            i++;
            let n, ok = parse_int(argv[i]);
            if !ok || n < 1 || n > 10000 { abort_args(); }
            options.frames = n;
        } else if flag == "--screenshot" {
            if i + 1 >= argv.len || output.len != 0 { abort_args(); }
            i++;
            output.append(argv[i]);
            if output.len == 0 { abort_args(); }
        } else { abort_args(); }
        i++;
    }
    if options.replay_input && (options.empty || options.preview) { abort_args(); }
    if options.seam_replay && options.single { abort_args(); }
    if options.seed_explicit && (options.demo || options.empty) { abort_args(); }
    if options.terrain_replay && options.demo { abort_args(); }
    if options.seam_replay && !options.demo { abort_args(); }
    if no_save && world_path.len > 0 { abort_args(); }
    if options.replay_input && options.frames < 0 { options.frames = if options.inventory_replay { 90 } else if options.paging_replay { 680 } else if options.stream_replay { 400 } else if options.terrain_replay { 120 } else { 110 }; }
    if options.offscreen && !options.replay_input && !options.paged { options.preview = true; }
    if options.empty { options.preview = true; }
    if options.away && !options.preview { abort_args(); }
    if view_given && (!options.preview || options.away) { abort_args(); }
    if options.raw && options.reference { abort_args(); }
    if warmup_given && profile_path.len == 0 { abort_args(); }
    if radius_given && options.single { abort_args(); }
    if !radius_given {
        options.radius = if options.paged || options.far_replay { 4 } else if options.preview || options.replay_input || options.demo || options.single { 1 } else { 4 };
    }
    if options.far_replay && (options.radius < 2 || options.single) { abort_args(); }
    if !mesh_radius_given {
        options.mesh_radius = if options.stream_replay || options.paging_replay { 1 } else if options.paged { 2 } else if options.preview || options.replay_input || options.demo || options.single { 0 } else { 2 };
    }
    if options.preview && options.mesh_radius != 0 { abort_args(); }
    if options.retain_meshes && options.mesh_radius == 0 { abort_args(); }
    if options.paged && (options.mesh_radius < 1 || options.mesh_radius > 2 || options.preview || options.demo || options.empty || options.single || options.retain_meshes) { abort_args(); }
    if options.tall && (options.demo || options.empty || options.single || options.deferred_respawn) { abort_args(); }
    if !options.paged && (options.sync_paging || prefetch_delay_given || page_delay_given) { abort_args(); }
    if options.sync_paging && prefetch_delay_given { abort_args(); }
    if options.deferred_respawn && (!options.paged || options.sync_paging) { abort_args(); }
    // Page/index/lock names cannot collide with diagnostic outputs. New PNGs
    // also avoid accidental replacement of a user's existing diagnostic file.
    if (options.paged || options.tall) && output.len > 0 && (output.len < 4 || output[output.len - 4..] != ".png" || file_exists(output) || is_dir(output)) { abort_args(); }
    if (options.paged || options.tall) && profile_path.len > 0 && (profile_path.len < 5 || profile_path[profile_path.len - 5..] != ".json") { abort_args(); }
    if output.len > 0 && output == world_path { abort_args(); }
    if options.offscreen && options.frames < 0 { options.frames = 3; }
    options.persistent = world_path.len > 0 || !(no_save || options.offscreen || options.preview || options.replay_input || options.single);
    if options.persistent && world_path.len == 0 { world_path.append(storage::default_path()); }
    if profile_path.len > 0 && (profile_path == world_path || profile_path == output) { abort_args(); }
    options.output = output; options.world_path = world_path;
    options.profile_path = profile_path;
    scene::run(options);
}

fn abort_args() {
    write_stderr("invalid graphics arguments: use --help\n");
    exit(2);
}
