// An original tiny bitmap alphabet: geometry only, no external fonts/assets.
import core.core;
namespace hud;

struct Key {
    size: int2 = int2 { 0, 0 },
    active: bool = false,
    selected: u8 = 0,
    found: bool = false,
    cell: int3 = int3 { 0, 0, 0 },
    broken: i64 = 0,
    placed: i64 = 0,
    save_status: i64 = 0,
    loading: bool = false,
    bag: inventory::State = inventory::State {},
    pointer: float2 = float2 { -1.0, -1.0 },
}

fn glyph(c: u8) -> u8[7] {
    let letters: u8[7][26] = [
        [14, 17, 17, 31, 17, 17, 17], [30, 17, 17, 30, 17, 17, 30],
        [14, 17, 16, 16, 16, 17, 14], [30, 17, 17, 17, 17, 17, 30],
        [31, 16, 16, 30, 16, 16, 31], [31, 16, 16, 30, 16, 16, 16],
        [14, 17, 16, 23, 17, 17, 15], [17, 17, 17, 31, 17, 17, 17],
        [14, 4, 4, 4, 4, 4, 14], [7, 2, 2, 2, 18, 18, 12],
        [17, 18, 20, 24, 20, 18, 17], [16, 16, 16, 16, 16, 16, 31],
        [17, 27, 21, 21, 17, 17, 17], [17, 25, 21, 19, 17, 17, 17],
        [14, 17, 17, 17, 17, 17, 14], [30, 17, 17, 30, 16, 16, 16],
        [14, 17, 17, 17, 21, 18, 13], [30, 17, 17, 30, 20, 18, 17],
        [15, 16, 16, 14, 1, 1, 30], [31, 4, 4, 4, 4, 4, 4],
        [17, 17, 17, 17, 17, 17, 14], [17, 17, 17, 17, 17, 10, 4],
        [17, 17, 17, 21, 21, 27, 17], [17, 17, 10, 4, 10, 17, 17],
        [17, 17, 10, 4, 4, 4, 4], [31, 1, 2, 4, 8, 16, 31],
    ];
    let digits: u8[7][10] = [
        [14, 17, 19, 21, 25, 17, 14], [4, 12, 4, 4, 4, 4, 14],
        [14, 17, 1, 2, 4, 8, 31], [30, 1, 1, 14, 1, 1, 30],
        [2, 6, 10, 18, 31, 2, 2], [31, 16, 16, 30, 1, 1, 30],
        [14, 16, 16, 30, 17, 17, 14], [31, 1, 2, 4, 8, 8, 8],
        [14, 17, 17, 14, 17, 17, 14], [14, 17, 17, 15, 1, 1, 14],
    ];
    if c >= 'A' && c <= 'Z' { return letters[c - 'A']; }
    if c >= '0' && c <= '9' { return digits[c - '0']; }
    if c == '/' { return [1, 2, 2, 4, 8, 8, 16]; }
    if c == '-' { return [0, 0, 0, 31, 0, 0, 0]; }
    if c == ':' { return [0, 4, 4, 0, 4, 4, 0]; }
    if c == '.' { return [0, 0, 0, 0, 0, 4, 4]; }
    return [0; 7];
}

fn rect(vertices: mesh::Vertex[>..]&, x: f32, y: f32, w: f32, h: f32,
        size: int2, color: u8[4]) {
    let a = float3 { x * 2.0 / size.x - 1.0, 1.0 - y * 2.0 / size.y, 0.0 };
    let b = float3 { (x + w) * 2.0 / size.x - 1.0, 1.0 - (y + h) * 2.0 / size.y, 0.0 };
    vertices.append([mesh::Vertex { a, color }, mesh::Vertex { float3 { b.x, a.y, 0.0 }, color },
                     mesh::Vertex { b, color }, mesh::Vertex { a, color }, mesh::Vertex { b, color },
                     mesh::Vertex { float3 { a.x, b.y, 0.0 }, color }]);
}

fn text(vertices: mesh::Vertex[>..]&, value: u8[:], x: f32, y: f32, size: int2, color: u8[4]) {
    var at = x;
    for c in value {
        let rows = glyph(c);
        for row in 7 {
            for col in 5 {
                if (rows[row] & (16 >> col)) != 0 {
                    rect(vertices, at + col * 2, y + row * 2, 2.0, 2.0, size, color);
                }
            }
        }
        at += 12.0;
    }
}

fn block_icon(vertices: mesh::Vertex[>..]&, x: f32, y: f32, edge: f32, size: int2, material: u8) {
    if material == 0 { return; }
    let color: u8[4] = if material == 1 { [108, 211, 134, 255] } else { [239, 174, 67, 255] };
    rect(vertices, x, y, edge, edge, size, color);
    rect(vertices, x, y, edge, 3.0, size, [224, 239, 220, 255]);
    rect(vertices, x, y + 3.0, 3.0, edge - 3.0, size, [51, 76, 59, 255]);
}

fn build(vertices: mesh::Vertex[>..]&, size: int2, active: bool, selected: u8,
         hit: interaction::Hit, broken: i64, placed: i64, save_status: i64, loading: bool,
         bag: inventory::State, pointer: float2) {
    vertices.clear();
    let ink: u8[4] = [232, 239, 245, 255];
    let muted: u8[4] = [161, 182, 202, 255];
    let warning: u8[4] = [255, 128, 112, 255];
    rect(vertices, 0.0, 0.0, size.x, 52.0, size, [16, 24, 33, 255]);
    text(vertices, "GOOSECRAFT 0.14.0", 12.0, 10.0, size, ink);
    text(vertices, if save_status == 0 { "TEMP" } else if save_status == 1 { "UNSAVED" }
                  else if save_status == 2 { "SAVED" } else { "SAVE ERROR" }, 224.0, 10.0, size,
         if save_status == 3 { warning } else { muted });
    text(vertices, str("BREAK ", broken, "  PLACE ", placed), 12.0, 30.0, size, muted);
    text(vertices, str(bag.selected + 1, if selected == 1 { " GREEN" } else if selected == 2 { " AMBER" } else { " EMPTY" }), size.x - 112.0, 10.0, size,
         if selected == 1 { [108, 211, 134, 255] } else { [239, 174, 67, 255] });
    if hit.found {
        text(vertices, str("BLOCK ", hit.cell.x, "/", hit.cell.y, "/", hit.cell.z),
             size.x - 208.0, 30.0, size, muted);
    }
    rect(vertices, 0.0, size.y - 64.0, size.x, 64.0, size, [16, 24, 33, 255]);
    text(vertices, "WASD MOVE  SPACE JUMP  MOUSE LOOK", 12.0, size.y - 54.0, size, ink);
    text(vertices, "LMB BREAK  RMB PLACE  1-9 SELECT  E BAG", 12.0, size.y - 36.0, size, ink);
    text(vertices, "ESC PAUSE  ENTER RESUME  F10 QUIT  R SPAWN  F5 SAVE", 12.0, size.y - 18.0, size, muted);
    let x = size.x * 0.5;
    let y = size.y * 0.5;
    if !bag.opened {
        rect(vertices, x - 7.0, y - 2.0, 15.0, 5.0, size, [16, 24, 33, 255]);
        rect(vertices, x - 2.0, y - 7.0, 5.0, 15.0, size, [16, 24, 33, 255]);
        rect(vertices, x - 6.0, y, 13.0, 1.0, size, ink);
        rect(vertices, x, y - 6.0, 1.0, 13.0, size, ink);
    }
    let hover = inventory::target(size.x, size.y, pointer.x, pointer.y);
    if bag.opened {
        let panel = inventory::panel_rect(size.x, size.y);
        rect(vertices, panel.x, panel.y, panel.w, panel.h, size, [16, 24, 33, 255]);
        text(vertices, "CREATIVE BLOCKS", panel.x + 24, panel.y + 18, size, ink);
        for item in 1..3 {
            let r = inventory::palette_rect(size.x, size.y, item);
            rect(vertices, r.x, r.y, r.w, r.h, size, if hover == item + 8 { [85, 103, 121, 255] } else { [39, 51, 65, 255] });
            block_icon(vertices, r.x + 22, r.y + 8, 28.0, size, item as u8);
            text(vertices, if item == 1 { "GREEN" } else { "AMBER" }, r.x + 6, r.y + 50, size, ink);
        }
        text(vertices, "UNLIMITED", panel.x + 24, panel.y + 144, size, muted);
        text(vertices, "LMB PICK / SWAP", panel.x + 24, panel.y + 174, size, ink);
        text(vertices, "RMB CLEAR SLOT", panel.x + 24, panel.y + 196, size, muted);
        text(vertices, "E / ESC CLOSE", panel.x + 24, panel.y + 226, size, muted);
    }
    for slot in 9 {
        let r = inventory::slot_rect(size.x, size.y, slot);
        rect(vertices, r.x, r.y, r.w, r.h, size, if slot == bag.selected { [239, 193, 92, 255] } else { [91, 111, 130, 255] });
        rect(vertices, r.x + 2, r.y + 2, r.w - 4, r.h - 4, size,
             if bag.opened && hover == slot { [68, 85, 102, 255] } else { [28, 39, 51, 255] });
        block_icon(vertices, r.x + r.w / 2 - 8, r.y + 6, 16.0, size, bag.slots[slot]);
        text(vertices, str(slot + 1), r.x + 4, r.y + 24, size, ink);
    }
    if bag.opened && bag.held > 0 { block_icon(vertices, pointer.x + 12.0, pointer.y + 12.0, 22.0, size, bag.held); }
    if loading {
        rect(vertices, x - 100.0, y - 30.0, 200.0, 54.0, size, [16, 24, 33, 255]);
        text(vertices, "LOADING", x - 42.0, y - 10.0, size, ink);
    } else if !active {
        rect(vertices, x - 210.0, y - 42.0, 420.0, 76.0, size, [16, 24, 33, 255]);
        text(vertices, "PAUSED", x - 36.0, y - 26.0, size, ink);
        text(vertices, "CLICK OR ENTER TO RESUME", x - 138.0, y + 2.0, size, muted);
    }
}

fn outline(vertices: mesh::Vertex[>..]&, hit: interaction::Hit) {
    vertices.clear();
    if !hit.found { return; }
    for axis in 3 {
        for a in 2 {
            for b in 2 {
                var p = float3 { hit.cell.x - 0.002, hit.cell.y - 0.002, hit.cell.z - 0.002 };
                if axis == 0 { p.y += a * 1.004; p.z += b * 1.004; }
                if axis == 1 { p.x += a * 1.004; p.z += b * 1.004; }
                if axis == 2 { p.x += a * 1.004; p.y += b * 1.004; }
                var q = p;
                if axis == 0 { q.x += 1.004; }
                if axis == 1 { q.y += 1.004; }
                if axis == 2 { q.z += 1.004; }
                vertices.append([mesh::Vertex { p, [255, 249, 214, 255] },
                                 mesh::Vertex { q, [255, 249, 214, 255] }]);
            }
        }
    }
}
