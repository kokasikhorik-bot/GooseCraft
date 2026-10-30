// Independent geometry oracle: clip triangles against voxel-sized squares.
// Checks actual indexed triangles, not the stitcher's fan construction/order.
import core from "../../src/core";
import math;
namespace triangles;

struct P { u: f64 = 0.0, v: f64 = 0.0 }

fn distance(p: P, edge: i64, u: i64, v: i64) -> f64 {
    if edge == 0 { return p.u - u; }
    if edge == 1 { return u + 1 - p.u; }
    if edge == 2 { return p.v - v; }
    return v + 1 - p.v;
}

fn area(a: P, b: P, c: P, u: i64, v: i64) -> f64 {
    var points: P[16] = [P {}; 16];
    points[0] = a; points[1] = b; points[2] = c;
    var count: i64 = 3;
    for edge in 4 {
        if count == 0 { return 0.0; }
        var next: P[16] = [P {}; 16];
        var size: i64 = 0;
        for i in count {
            let current = points[i];
            let previous = points[(i + count - 1) % count];
            let d = distance(current, edge, u, v);
            let before = distance(previous, edge, u, v);
            if (d >= 0.0) != (before >= 0.0) {
                let t = before / (before - d);
                next[size] = P { previous.u + t * (current.u - previous.u),
                                  previous.v + t * (current.v - previous.v) }; size++;
            }
            if d >= 0.0 { next[size] = current; size++; }
        }
        points = next; count = size;
    }
    var sum: f64 = 0.0;
    for i in count {
        let a = points[i]; let b = points[(i + 1) % count];
        sum += (a.u - u) * (b.v - v) - (b.u - u) * (a.v - v);
    }
    return abs(sum) * 0.5;
}

fn rgba(color: u8[4]) -> u32 {
    color[0] | ((color[1] as u32) << 8) | ((color[2] as u32) << 16) | ((color[3] as u32) << 24)
}

fn coverage(vertices: mesh::Vertex[:], indices: u32[:], expected: u32[:]) -> bool {
    if indices.len % 3 != 0 { return false; }
    var covered: f64[24576] = [0.0; 24576];
    for t in indices.len / 3 {
        for i in 3 { if indices[t * 3 + i] >= vertices.len { return false; } }
        let a = vertices[indices[t * 3]];
        let b = vertices[indices[t * 3 + 1]];
        let c = vertices[indices[t * 3 + 2]];
        if a.color != b.color || a.color != c.color || a.color[3] != 255 { return false; }
        let normal = cross(b.position - a.position, c.position - a.position);
        let components: f32[3] = [normal.x, normal.y, normal.z];
        var axis: i64 = -1;
        for i in 3 { if components[i] != 0.0 { if axis != -1 { return false; } axis = i; } }
        if axis == -1 { return false; } // Degenerate or non-axis-aligned triangle.
        let aa: f32[3] = [a.position.x, a.position.y, a.position.z];
        let bb: f32[3] = [b.position.x, b.position.y, b.position.z];
        let cc: f32[3] = [c.position.x, c.position.y, c.position.z];
        let plane = aa[axis];
        if plane != floor(plane) || plane != bb[axis] || plane != cc[axis] { return false; }
        let u_axis = (axis + 1) % 3; let v_axis = (axis + 2) % 3;
        let pa = P { aa[u_axis], aa[v_axis] };
        let pb = P { bb[u_axis], bb[v_axis] };
        let pc = P { cc[u_axis], cc[v_axis] };
        let lower_u = floor(min(pa.u, min(pb.u, pc.u))) as i64;
        let lower_v = floor(min(pa.v, min(pb.v, pc.v))) as i64;
        let upper_u = ceil(max(pa.u, max(pb.u, pc.u))) as i64;
        let upper_v = ceil(max(pa.v, max(pb.v, pc.v))) as i64;
        if lower_u < 0 || lower_v < 0 || upper_u > 16 || upper_v > 16 { return false; }
        let positive = components[axis] > 0.0;
        let n = plane as i64 - (if positive { 1 } else { 0 });
        if n < 0 || n >= 16 { return false; }
        let face = axis * 2 + (if positive { 0 } else { 1 });
        for v in lower_v..upper_v { for u in lower_u..upper_u {
            let part = area(pa, pb, pc, u, v);
            if part < 0.000000001 { continue; }
            var x = u; var y = v; var z = n;
            if axis == 0 { x = n; y = u; z = v; }
            if axis == 1 { x = v; y = n; z = u; }
            let slot = face * 4096 + x + 16 * (z + 16 * y);
            if expected[slot] == 0 || expected[slot] != rgba(a.color) { return false; }
            covered[slot] += part;
            if covered[slot] > 1.0000001 { return false; }
        } }
    }
    for i in expected.len {
        let wanted: f64 = if expected[i] == 0 { 0.0 } else { 1.0 };
        if abs(covered[i] - wanted) > 0.0000001 { return false; }
    }
    return true;
}

fn gcd(a: i64, b: i64) -> i64 {
    var x = abs(a); var y = abs(b);
    while y != 0 { let next = x % y; x = y; y = next; }
    return x;
}

// Half-grid positions cover integer corners and half-integer fan centers.
// extent=48 also checks a whole 3x3 world, across independently built seams.
fn no_t_junctions(vertices: mesh::Vertex[:], indices: u32[:], extent: i64 = 16) -> bool {
    assert(extent > 0 && extent <= 48);
    let size = extent * 2 + 1;
    var occupied: u64[14261] = [0; 14261]; // ceil(97^3 / 64), bounded 114088 bytes.
    let one: u64 = 1;
    for vertex in vertices {
        let p = vertex.position * 2.0;
        if p.x < 0.0 || p.y < 0.0 || p.z < 0.0 || p.x > extent * 2 || p.y > extent * 2 || p.z > extent * 2 ||
           p.x != floor(p.x) || p.y != floor(p.y) || p.z != floor(p.z) { return false; }
        let at = (p.x as i64) + size * ((p.y as i64) + size * (p.z as i64));
        occupied[at / 64] |= one << (at % 64);
    }
    for triangle in indices.len / 3 { for edge in 3 {
        let a = vertices[indices[triangle * 3 + edge]].position * 2.0;
        let b = vertices[indices[triangle * 3 + (edge + 1) % 3]].position * 2.0;
        let dx = (b.x - a.x) as i64; let dy = (b.y - a.y) as i64; let dz = (b.z - a.z) as i64;
        let steps = gcd(gcd(dx, dy), dz);
        if steps == 0 { return false; }
        for i in 1..steps {
            let x = a.x as i64 + dx / steps * i;
            let y = a.y as i64 + dy / steps * i;
            let z = a.z as i64 + dz / steps * i;
            let at = x + size * (y + size * z);
            if (occupied[at / 64] & (one << (at % 64))) != 0 { return false; }
        }
    } }
    return true;
}
