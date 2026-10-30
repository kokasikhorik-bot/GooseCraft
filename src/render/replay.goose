// Deterministic integration probe using the pinned gfx input event API.
// It shares the normal input/physics/editing/rendering path, and supplies
// 1/60 s per frame instead of depending on a software GPU's frame time.
namespace replay;

fn key(name: u8[:], down: bool) { assert(gfx::inject_key(name, down)); }

// Terrain path uses normal mouse, movement, jumping, editing and save handlers.
fn terrain_input(frame: i64) {
    if frame == 0 { gfx::inject_mouse(320.0, 240.0, 0, false); }
    if frame == 1 { gfx::inject_mouse(320.0, 440.0, 0, false); }
    if frame == 2 { gfx::inject_mouse(320.0, 440.0, gfx::MOUSE_LEFT, true); }
    if frame == 3 { gfx::inject_mouse(320.0, 440.0, gfx::MOUSE_LEFT, false); }
    if frame == 6 { key("2", true); }
    if frame == 7 { key("2", false); gfx::inject_mouse(320.0, 440.0, gfx::MOUSE_RIGHT, true); }
    if frame == 8 { gfx::inject_mouse(320.0, 440.0, gfx::MOUSE_RIGHT, false); }
    if frame == 10 { gfx::inject_mouse(320.0, 300.0, 0, false); key("D", true); }
    if frame == 20 || frame == 75 { key("Space", true); }
    if frame == 21 || frame == 76 { key("Space", false); }
    if frame == 95 { key("D", false); }
    if frame == 110 { key("F5", true); }
    if frame == 111 { key("F5", false); }
}

// Walk out far enough to evict the edited starting chunk, then use the normal
// R handler to return. No direct mutation of player, blocks or cache state.
fn stream_input(frame: i64) {
    terrain_input(frame);
    if frame == 96 { key("D", true); }
    if frame >= 100 && frame < 350 && frame % 40 == 20 { key("Space", true); }
    if frame >= 100 && frame < 350 && frame % 40 == 21 { key("Space", false); }
    if frame == 350 { key("D", false); }
    if frame == 360 { key("R", true); }
    if frame == 361 { key("R", false); }
    if frame == 380 { key("F5", true); }
    if frame == 381 { key("F5", false); }
}

fn paging_input(frame: i64) {
    terrain_input(frame);
    if frame == 96 { key("D", true); }
    if frame >= 100 && frame < 600 && frame % 40 == 20 { key("Space", true); }
    if frame >= 100 && frame < 600 && frame % 40 == 21 { key("Space", false); }
    if frame == 600 { key("D", false); }
    if frame == 620 { key("R", true); }
    if frame == 621 { key("R", false); }
    if frame == 660 { key("F5", true); }
    if frame == 661 { key("F5", false); }
}

fn inject(frame: i64, seam: bool) {
    if frame == 0 { gfx::inject_mouse(320.0, 240.0, 0, false); }
    if frame == 2 { gfx::inject_mouse(320.0, 240.0, gfx::MOUSE_LEFT, true); }
    if frame == 3 { gfx::inject_mouse(320.0, 240.0, gfx::MOUSE_LEFT, false); }
    if frame == 5 { gfx::inject_mouse(320.0, 180.0, 0, false); }
    if frame == 6 { key("2", true); }
    if frame == 7 { key("2", false); gfx::inject_mouse(320.0, 180.0, gfx::MOUSE_RIGHT, true); }
    if frame == 8 { gfx::inject_mouse(320.0, 180.0, gfx::MOUSE_RIGHT, false); }
    if frame == 12 { key("1", true); }
    if frame == 13 { key("1", false); }
    if frame == 15 { key("W", true); }
    if frame == 25 { key("Space", true); }
    if frame == 26 { key("Space", false); }
    if frame == 50 { key("W", false); if seam { key("D", true); } }
    if frame == 52 && !seam { key("D", true); }
    if frame == 57 && !seam { key("D", false); }
    if frame == 60 { key("Escape", true); if seam { key("D", false); } }
    if frame == 61 { key("Escape", false); key("W", true); }
    if frame == 64 { key("Return", true); }
    if frame == 65 { key("Return", false); }
    if frame == 70 { assert(gfx::inject_focus(false)); }
    if frame == 71 { key("W", true); }
    if frame == 73 { assert(gfx::inject_focus(true)); }
    if frame == 75 { key("Return", true); }
    if frame == 76 { key("Return", false); }
    if frame == 80 { gfx::inject_mouse(360.0, 180.0, 0, false); }
    if frame == 83 { key("R", true); }
    if frame == 84 { key("R", false); }
    if frame == 90 { key("Escape", true); }
    if frame == 91 { key("Escape", false); }
    if frame == 95 { key("Return", true); }
    if frame == 96 { key("Return", false); }
    if frame == 100 { key("F5", true); }
    if frame == 101 { key("F5", false); }
}
