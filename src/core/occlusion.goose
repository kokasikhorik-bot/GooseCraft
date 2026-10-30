// Optional vertex ambient occlusion. CPU-only, no graphics or platform API.
import .mesh;
namespace occlusion;

// Canonical corners in cyclic U/V: (0,0), (1,0), (1,1), (0,1).
// The two side samples and diagonal lie in the air layer outside the face.
fn level<T>(source: T&, x: i64, y: i64, z: i64, face: i64, corner: i64) -> u8 {
    let axis = face / 2;
    var p: i64[3] = [x, y, z];
    p[axis] += if face % 2 == 0 { 1 } else { -1 };
    let u = (axis + 1) % 3; let v = (axis + 2) % 3;
    let du: i64 = if corner == 1 || corner == 2 { 1 } else { -1 };
    let dv: i64 = if corner >= 2 { 1 } else { -1 };
    p[u] += du;
    let side_u = mesh::solid(source, p[0], p[1], p[2]);
    p[u] -= du; p[v] += dv;
    let side_v = mesh::solid(source, p[0], p[1], p[2]);
    p[u] += du;
    let diagonal = mesh::solid(source, p[0], p[1], p[2]);
    if side_u && side_v { return 0; }
    return (3 - (if side_u { 1 } else { 0 }) - (if side_v { 1 } else { 0 }) -
            (if diagonal { 1 } else { 0 })) as u8;
}

// Material in bits 0..1, four two-bit light levels in bits 2..9.
fn key<T>(source: T&, x: i64, y: i64, z: i64, face: i64, material: u8) -> u16 {
    var value: u16 = material;
    for c in 4 { value |= (level(source, x, y, z, face, c) as u16) << (2 + c * 2); }
    return value;
}
fn uniform(value: u16) -> bool {
    let first = (value >> 2) & 3;
    for c in 1..4 { if ((value >> (2 + c * 2)) & 3) != first { return false; } }
    return true;
}
fn color(value: u16, face: i64, corner: i64, neutral: bool = false) -> u8[4] {
    let light: f32[6] = [0.78, 0.58, 1.0, 0.42, 0.7, 0.62];
    let tint: u8[3] = if neutral { [255; 3] } else if (value & 3) == 1 { [72, 165, 102] } else { [239, 174, 67] };
    let factors: u32[4] = [128, 166, 210, 255];
    let factor = factors[(value >> (2 + corner * 2)) & 3];
    var result: u8[4] = [0, 0, 0, 255];
    for channel in 3 {
        let base = (tint[channel] * light[face]) as! u8;
        result[channel] = (base * factor / 255) as! u8;
    }
    return result;
}

fn quad(vertices: mesh::Vertex[>..]&, indices: u32[>..]&, face: i64, slice: i64,
        u: i64, v: i64, width: i64, height: i64, value: u16, neutral: bool) {
    let axis = face / 2; let positive = face % 2 == 0;
    let n: f32 = slice + (if positive { 1 } else { 0 });
    let first_v = if positive { v } else { v + height };
    let last_v = if positive { v + height } else { v };
    let a = mesh::Vertex { mesh::point(axis, n, u, first_v), color(value, face, if positive { 0 } else { 3 }, neutral) };
    let b = mesh::Vertex { mesh::point(axis, n, u + width, first_v), color(value, face, if positive { 1 } else { 2 }, neutral) };
    let c = mesh::Vertex { mesh::point(axis, n, u + width, last_v), color(value, face, if positive { 2 } else { 1 }, neutral) };
    let d = mesh::Vertex { mesh::point(axis, n, u, last_v), color(value, face, if positive { 3 } else { 0 }, neutral) };
    let base = vertices.len as u32;
    if axis == 0 { vertices.push(a); vertices.push(b); vertices.push(c); vertices.push(d); }
    else if positive { vertices.push(b); vertices.push(c); vertices.push(d); vertices.push(a); }
    else { vertices.push(d); vertices.push(a); vertices.push(b); vertices.push(c); }
    // Fixed reference diagonal. Nonuniform faces stay unit-sized, including
    // during stitching; no interpolation across a merged lighting boundary.
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

fn build_reference<T>(source: T&, vertices: mesh::Vertex[>..]&, indices: u32[>..]&, neutral: bool = false) {
    assert(vertices.len == 0 && indices.len == 0);
    let steps: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    for y in 16 { for z in 16 { for x in 16 {
        let id = world::get(source, x, y, z);
        if id == 0 { continue; }
        let p: i64[3] = [x, y, z];
        for face in 6 {
            let step = steps[face];
            if mesh::solid(source, x + step[0], y + step[1], z + step[2]) { continue; }
            let axis = face / 2;
            quad(vertices, indices, face, p[axis], p[(axis + 1) % 3], p[(axis + 2) % 3],
                 1, 1, key(source, x, y, z, face, id), neutral);
        }
    } } }
}

fn build<T>(source: T&, vertices: mesh::Vertex[>..]&, indices: u32[>..]&, neutral: bool = false) {
    assert(vertices.len == 0 && indices.len == 0);
    // 49,152 mask bytes. The legacy builder and its 24,576-byte masks stay
    // separate: disabling AO does not pay for the wider key or extra sampling.
    var masks: u16[24576] = [0; 24576];
    var used: bool[96] = [false; 96];
    let steps: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    for y in 16 { for z in 16 { for x in 16 {
        let id = world::get(source, x, y, z);
        if id == 0 { continue; }
        let p: i64[3] = [x, y, z];
        for face in 6 {
            let step = steps[face];
            if mesh::solid(source, x + step[0], y + step[1], z + step[2]) { continue; }
            let axis = face / 2; let plane = face * 16 + p[axis];
            masks[plane * 256 + p[(axis + 2) % 3] * 16 + p[(axis + 1) % 3]] = key(source, x, y, z, face, id);
            used[plane] = true;
        }
    } } }
    for face in 6 { for slice in 16 {
        let plane = face * 16 + slice;
        if !used[plane] { continue; }
        let offset = plane * 256;
        for v in 16 {
            var u: i64 = 0;
            while u < 16 {
                let value = masks[offset + v * 16 + u];
                if value == 0 { u++; continue; }
                var width: i64 = 1; var height: i64 = 1;
                if uniform(value) {
                    while u + width < 16 && masks[offset + v * 16 + u + width] == value { width++; }
                    while v + height < 16 {
                        var same = true;
                        for col in width { if masks[offset + (v + height) * 16 + u + col] != value { same = false; break; } }
                        if !same { break; }
                        height++;
                    }
                }
                quad(vertices, indices, face, slice, u, v, width, height, value, neutral);
                for row in height { for col in width { masks[offset + (v + row) * 16 + u + col] = 0; } }
                u += width;
            }
        }
    } }
}

// An edit can change corner light in a diagonally adjacent section too.
// Touch only metadata; do not read/load Paged blocks or change save state.
fn invalidate<T>(map: T&, cell: int3) {
    for at in world::slots(map) {
        if !world::active(map, at) { continue; }
        let x = world::chunk_x(map, at) * 16;
        let y = world::chunk_y(map, at) * 16;
        let z = world::chunk_z(map, at) * 16;
        if cell.x >= x - 1 && cell.x <= x + 16 && cell.y >= y - 1 && cell.y <= y + 16 &&
           cell.z >= z - 1 && cell.z <= z + 16 { map.dirty[at] = true; }
    }
}
