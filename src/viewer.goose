// This local package is fetched and verified by tools/bootstrap.py --graphics.
import gfx from "../.cache/upstream/goose_gfx";
import os;
import std;
import render.scene;

fn main() {
    let argv = args();
    var offscreen = false;
    var empty = false;
    var frames: i64 = -1;
    var output: u8[>..] = [];
    var i: i64 = 1;
    while i < argv.len {
        let flag = argv[i];
        if flag == "--help" {
            print("GooseCraft 0.2.0: graphical scene");
            print("usage: goosecraft-client [--offscreen] [--empty] [--frames N] [--screenshot FILE]");
            print("Escape closes the window. This is a graphics prototype.");
            return;
        } else if flag == "--offscreen" { offscreen = true; }
        else if flag == "--empty" { empty = true; }
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
    if offscreen && frames < 0 { frames = 3; }
    scene::run(offscreen, empty, frames, output);
}

fn abort_args() {
    write_stderr("invalid graphics arguments: use --help\n");
    exit(2);
}
