// This local package is fetched and verified by tools/bootstrap.py --graphics.
import gfx from "../.cache/upstream/goose_gfx";
import os;
import std;
import render.scene;

fn main() {
    let argv = args();
    var offscreen = false;
    var empty = false;
    var preview = false;
    var replay_input = false;
    var frames: i64 = -1;
    var output: u8[>..] = [];
    var i: i64 = 1;
    while i < argv.len {
        let flag = argv[i];
        if flag == "--help" {
            print("GooseCraft 0.3.0: graphical scene and playable voxel prototype");
            print("usage: goosecraft-client [--preview | --replay] [--offscreen] [--empty] [--frames N] [--screenshot FILE]");
            print("WASD move; mouse/arrows look; Space jump; LMB break; RMB place; 1/2 block.");
            print("Escape pauses; click/Enter resumes; R respawns; F10 quits. World changes are not saved.");
            return;
        } else if flag == "--offscreen" { offscreen = true; }
        else if flag == "--empty" { empty = true; }
        else if flag == "--preview" { preview = true; }
        else if flag == "--replay" { replay_input = true; }
        else if flag == "--frames" {
            if i + 1 >= argv.len { abort_args(); }
            i++;
            let n, ok = parse_int(argv[i]);
            if !ok || n < 1 || n > 10000 { abort_args(); }
            frames = n;
        } else if flag == "--screenshot" {
            if i + 1 >= argv.len || output.len != 0 { abort_args(); }
            i++;
            output.append(argv[i]);
            if output.len == 0 { abort_args(); }
        } else { abort_args(); }
        i++;
    }
    if replay_input && (empty || preview) { abort_args(); }
    if replay_input && frames < 0 { frames = 110; }
    if offscreen && !replay_input { preview = true; }
    if empty { preview = true; }
    if offscreen && frames < 0 { frames = 3; }
    scene::run(offscreen, empty, frames, output, preview, replay_input);
}

fn abort_args() {
    write_stderr("invalid graphics arguments: use --help\n");
    exit(2);
}
