// GooseCraft's original tiles. No files or third-party game resources.
import .mesh;
import math;
namespace textures;

let EDGE: i64 = 16;
let LAYERS: i64 = 4;
struct Vertex { position: float3, color: u8[4], tile: u8[4] }

fn pixel(layer: i64, x: i64, y: i64) -> u8[4] {
    assert(layer >= 0 && layer < 4 && x >= 0 && x < 16 && y >= 0 && y < 16);
    let n = (x * 17 + y * 29 + x * y * 7 + layer * 11) % 31;
    let fleck = (x * 13 + y * 19) % 23 == 0;
    let grass = layer == 0 || (layer == 1 && y < 3 + (x * 7 % 3));
    if grass {
        return [(47 + n / 2) as u8, (126 + n) as u8, (61 + n / 3) as u8, 255];
    }
    if layer == 3 {
        let vein = (y + x / 4) % 7 == 0;
        return [(if vein { 145 + n } else { 183 + n }) as u8,
                (if vein { 96 + n / 2 } else { 132 + n / 2 }) as u8,
                (if fleck { 82 } else { 55 + n / 3 }) as u8, 255];
    }
    return [(if fleck { 93 } else { 111 + n }) as u8, (74 + n / 2) as u8, (43 + n / 3) as u8, 255];
}

fn pixels() -> u8[4096] {
    var result: u8[4096] = [0; 4096];
    for layer in 4 { for y in 16 { for x in 16 {
        let rgba = pixel(layer, x, y);
        for c in 4 { result[((layer * 16 + y) * 16 + x) * 4 + c] = rgba[c]; }
    } } }
    return result;
}
fn layer(material: u8, face: i64) -> u8 {
    assert(material == 1 || material == 2);
    if material == 2 { return 3; }
    if face == 2 { return 0; }
    if face == 3 { return 2; }
    return 1;
}

// Affine projection in block units, also used by the GPU vertex shader.
// Local section origins are multiples of 16, so repeating UV phase agrees
// with world coordinates, including negative X/Y/Z and independently built seams.
fn uv(p: float3, axis: i64) -> float2 {
    if axis == 0 { return float2 { p.z, -p.y }; }
    if axis == 1 { return float2 { p.x, p.z }; }
    return float2 { p.x, -p.y };
}

// Input is the unstitched quad list. Existing builders already join only
// equal material/orientation/light; tile selection depends on those alone.
fn convert<T>(source: T&, input: mesh::Vertex[:], output: Vertex[>..]&) {
    assert(input.len % 4 == 0 && output.len == 0);
    for q in input.len / 4 {
        let base = q * 4;
        let a = input[base].position; let b = input[base + 1].position; let c = input[base + 2].position;
        let normal = cross(b - a, c - a);
        let axis: i64 = if normal.x != 0.0 { 0 } else if normal.y != 0.0 { 1 } else { 2 };
        let positive = normal.x + normal.y + normal.z > 0.0;
        let face = axis * 2 + (if positive { 0 } else { 1 });
        var lo = a;
        for i in 1..4 {
            let p = input[base + i].position;
            lo = float3 { min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
        }
        var cell: i64[3] = [lo.x as i64, lo.y as i64, lo.z as i64];
        if positive { cell[axis]--; }
        let material = world::get(source, cell[0], cell[1], cell[2]);
        let tile: u8[4] = [axis as u8, layer(material, face), 0, 0];
        for i in 4 { output.push(Vertex { input[base + i].position, input[base + i].color, tile }); }
    }
}
