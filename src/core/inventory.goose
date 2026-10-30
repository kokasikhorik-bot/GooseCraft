// Session-local creative block palette. World material IDs remain 0/1/2.
namespace inventory;

struct State {
    slots: u8[9] = [1, 2, 0, 0, 0, 0, 0, 0, 0],
    selected: i64 = 0, opened: bool = false, held: u8 = 0,
}
struct Rect { x: i64 = 0, y: i64 = 0, w: i64 = 0, h: i64 = 0 }
fn material(state: State&) -> u8 { state.slots[state.selected] }
fn select(state: State&, slot: i64) -> bool {
    if slot < 0 || slot >= 9 { return false; }
    state.selected = slot; return true;
}
fn close(state: State&) { state.opened = false; state.held = 0; }
fn toggle(state: State&) { state.opened = !state.opened; state.held = 0; }
// Targets 0..8 are hotbar slots, 9/10 are palette entries. Invalid clicks do nothing.
fn click(state: State&, target: i64, right: bool) -> bool {
    if !state.opened || target < 0 || target > 10 { return false; }
    if target >= 9 { state.held = if right { 0 } else { (target - 8) as u8 }; return true; }
    state.selected = target;
    if right { state.slots[target] = 0; }
    else { let previous = state.slots[target]; state.slots[target] = state.held; state.held = previous; }
    return true;
}
fn slot_rect(width: i64, height: i64, slot: i64) -> Rect {
    assert(slot >= 0 && slot < 9);
    let step = clamp((width - 24) / 9, 20, 44);
    return Rect { (width - 9 * step) / 2 + slot * step, height - 112, step - 4, 40 };
}
fn panel_rect(width: i64, height: i64) -> Rect {
    let w = max(260, min(480, width - 24)); return Rect { (width - w) / 2, max(60, (height - 324) / 2), w, 324 };
}
fn palette_rect(width: i64, height: i64, item: i64) -> Rect {
    assert(item == 1 || item == 2); let panel = panel_rect(width, height);
    return Rect { panel.x + 24 + (item - 1) * 104, panel.y + 56, 72, 72 };
}
fn contains(rect: Rect, x: f32, y: f32) -> bool {
    x >= rect.x && x < rect.x + rect.w && y >= rect.y && y < rect.y + rect.h
}
fn target(width: i64, height: i64, x: f32, y: f32) -> i64 {
    for slot in 9 { if contains(slot_rect(width, height, slot), x, y) { return slot; } }
    for item in 1..3 { if contains(palette_rect(width, height, item), x, y) { return item + 8; } }
    return -1;
}
