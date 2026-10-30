import core from "../src/core";
import .support.surface;
import .support.triangles;

fn truth_table() {
    // Independent explicit face bases: N, U, V. All orientations and corners.
    let normals: int3[6] = [int3 { 1, 0, 0 }, int3 { -1, 0, 0 }, int3 { 0, 1, 0 },
                           int3 { 0, -1, 0 }, int3 { 0, 0, 1 }, int3 { 0, 0, -1 }];
    let us: int3[3] = [int3 { 0, 1, 0 }, int3 { 0, 0, 1 }, int3 { 1, 0, 0 }];
    let vs: int3[3] = [int3 { 0, 0, 1 }, int3 { 1, 0, 0 }, int3 { 0, 1, 0 }];
    let expected: u8[8] = [3, 2, 2, 0, 2, 1, 1, 0];
    for face in 6 { for c in 4 { for mask in 8 {
        var source = world::Chunk {};
        let center = int3 { 8, 8, 8 }; let outside = center + normals[face];
        let u = us[face / 2] * (if c == 1 || c == 2 { 1 } else { -1 });
        let v = vs[face / 2] * (if c >= 2 { 1 } else { -1 });
        let positions: int3[3] = [outside + u, outside + v, outside + u + v];
        for i in 3 { if (mask & (1 << i)) != 0 {
            let p = positions[i]; world::set(source, p.x, p.y, p.z, if i == 1 { 2 } else { 1 });
        } }
        assert(occlusion::level(source, 8, 8, 8, face, c) == expected[mask]);
    } } }
    // Explicit known +Y colors: full light / diagonal / side+diagonal / two sides.
    let levels: u16[4] = [3, 2, 1, 0];
    let colors: u8[4][4] = [[72, 165, 102, 255], [59, 135, 84, 255], [46, 107, 66, 255], [36, 82, 51, 255]];
    for i in 4 { assert(occlusion::color(1 | (levels[i] << 2), 2, 0) == colors[i]); }
}

// Expand both builders into unit faces and check each vertex against the
// actual neighboring voxel positions. No production key/color/level helpers.
fn validate<T>(source: T&, vertices: mesh::Vertex[:], output: bool[:]) {
    let normals: int3[6] = [int3 { 1, 0, 0 }, int3 { -1, 0, 0 }, int3 { 0, 1, 0 },
                           int3 { 0, -1, 0 }, int3 { 0, 0, 1 }, int3 { 0, 0, -1 }];
    let base_green: u8[3][6] = [[56, 128, 79], [41, 95, 59], [72, 165, 102], [30, 69, 42], [50, 115, 71], [44, 102, 63]];
    let base_amber: u8[3][6] = [[186, 135, 52], [138, 100, 38], [239, 174, 67], [100, 73, 28], [167, 121, 46], [148, 107, 41]];
    for q in vertices.len / 4 {
        let at = q * 4;
        let a = vertices[at].position; let b = vertices[at + 1].position; let c = vertices[at + 2].position;
        let n = cross(b - a, c - a);
        let axis: i64 = if n.x != 0.0 { 0 } else if n.y != 0.0 { 1 } else { 2 };
        let positive = n.x + n.y + n.z > 0.0;
        let face = axis * 2 + (if positive { 0 } else { 1 });
        var lo: f32[3] = [16.0; 3]; var hi: f32[3] = [0.0; 3];
        for i in 4 {
            let p = vertices[at + i].position; let xyz: f32[3] = [p.x, p.y, p.z];
            for k in 3 { lo[k] = min(lo[k], xyz[k]); hi[k] = max(hi[k], xyz[k]); }
        }
        let u = (axis + 1) % 3; let v = (axis + 2) % 3;
        let merged = hi[u] - lo[u] > 1.0 || hi[v] - lo[v] > 1.0;
        if merged { for i in 4 { assert(vertices[at + i].color == vertices[at].color); } }
        for vv in (lo[v] as i64)..(hi[v] as i64) { for uu in (lo[u] as i64)..(hi[u] as i64) {
            var cell: i64[3] = [0; 3]; cell[axis] = lo[axis] as i64 - (if positive { 1 } else { 0 }); cell[u] = uu; cell[v] = vv;
            let slot = face * 4096 + world::index(cell[0], cell[1], cell[2]);
            assert(!output[slot]); output[slot] = true;
            let id = world::sample(source, cell[0], cell[1], cell[2]); assert(id != 0);
            let base = if id == 1 { base_green[face] } else { base_amber[face] };
            for corner in 4 {
                let du: i64 = if corner == 1 || corner == 2 { 1 } else { -1 };
                let dv: i64 = if corner >= 2 { 1 } else { -1 };
                var tap = cell; tap[axis] += if positive { 1 } else { -1 };
                assert(world::sample(source, tap[0], tap[1], tap[2]) == 0);
                tap[u] += du; let s1 = world::sample(source, tap[0], tap[1], tap[2]) != 0;
                tap[u] -= du; tap[v] += dv; let s2 = world::sample(source, tap[0], tap[1], tap[2]) != 0;
                tap[u] += du; let s3 = world::sample(source, tap[0], tap[1], tap[2]) != 0;
                let factor: i64 = if s1 && s2 { 128 } else if (s1 && s3) || (s2 && s3) { 166 }
                                  else if s1 || s2 || s3 { 210 } else { 255 };
                let expected: u8[4] = [(base[0] * factor / 255) as! u8, (base[1] * factor / 255) as! u8,
                                      (base[2] * factor / 255) as! u8, 255];
                var found = merged;
                if merged { assert(vertices[at].color == expected); }
                else { for i in 4 {
                    let p = vertices[at + i].position; let xyz: f32[3] = [p.x, p.y, p.z];
                    if xyz[u] == uu + (if du == 1 { 1 } else { 0 }) && xyz[v] == vv + (if dv == 1 { 1 } else { 0 }) {
                        assert(vertices[at + i].color == expected); found = true;
                    }
                } }
                assert(found);
            }
        } }
    }
}

fn verify<T>(source: T&, expected_quads: i64 = -1) {
    var reference: mesh::Vertex[>..] = []; var reference_indices: u32[>..] = [];
    var vertices: mesh::Vertex[>..] = []; var indices: u32[>..] = [];
    occlusion::build_reference(source, reference, reference_indices); occlusion::build(source, vertices, indices);
    if expected_quads >= 0 { assert(vertices.len == expected_quads * 4); }
    var a: bool[24576] = [false; 24576]; var b: bool[24576] = [false; 24576];
    validate(source, reference, a); validate(source, vertices, b); assert(a == b);
    // The established independent triangle clipper proves coverage/winding
    // against legacy unit faces. Color correctness is checked above separately.
    var legacy: mesh::Vertex[>..] = []; var legacy_indices: u32[>..] = [];
    mesh::build_reference(source, legacy, legacy_indices);
    var coverage: u32[24576] = [0; 24576]; surface::coverage(source, legacy, legacy_indices, coverage);
    for i in coverage.len { assert((coverage[i] != 0) == a[i]); }
    let original = copy(vertices);
    stitch::apply(vertices, indices);
    for i in original.len { assert(vertices[i] == original[i]); }
    for t in indices.len / 3 {
        let ia = indices[t * 3]; let ib = indices[t * 3 + 1]; let ic = indices[t * 3 + 2];
        if vertices[ia].color == vertices[ib].color && vertices[ia].color == vertices[ic].color { continue; }
        assert(ia < original.len && ib < original.len && ic < original.len && ia / 4 == ib / 4 && ia / 4 == ic / 4);
        assert((ia % 4 == 0 && ib % 4 == 1 && ic % 4 == 2) || (ia % 4 == 0 && ib % 4 == 2 && ic % 4 == 3));
    }
    assert(triangles::coverage(vertices, indices, coverage, true));
    assert(triangles::no_t_junctions(vertices, indices));
    if indices.len > 0 { assert(!triangles::coverage(vertices, indices[..indices.len - 3], coverage, true)); }
}

fn invalidation() {
    var map = world::create(1); occlusion::invalidate(map, int3 { 15, 1, 15 });
    assert(world::pending(map) == 4 && map.dirty[world::slot(1, 1)]);
    var tall = world::create_tall(1); tall.dirty = [false; 324];
    occlusion::invalidate(tall, int3 { -1, -1, -1 }); assert(world::pending(tall) == 8);
    assert(tall.dirty[world::section_slot(tall, 0, 0, 0)] && tall.revision == 0);
    tall.dirty = [false; 324]; occlusion::invalidate(tall, int3 { 8, 8, 8 }); assert(world::pending(tall) == 1);
    // Lighting crosses an XYZ corner: changing only the diagonal section's
    // block must darken a vertex, and invalidate the source mesh.
    world::set(tall, 0, 0, 0, 1);
    let at = world::section_slot(tall, 0, 0, 0); var halo = world::neighborhood(tall, at);
    assert(occlusion::level(halo, 0, 0, 0, 1, 0) == 3);
    tall.dirty = [false; 324]; world::set(tall, -1, -1, -1, 2); occlusion::invalidate(tall, int3 { -1, -1, -1 });
    halo = world::neighborhood(tall, at); assert(occlusion::level(halo, 0, 0, 0, 1, 0) == 2 && tall.dirty[at]);
    verify(halo);
}

fn main() {
    truth_table(); invalidation();
    var empty = world::Chunk {}; verify(empty, 0);
    world::set(empty, 0, 0, 0, 1); verify(empty, 6);
    var flat = world::flat_fixture(); verify(flat, 6);
    var demo = world::demo_fixture(); verify(demo);
    for seed in 3 {
        var map = world::generate_tall(seed as u32, 1);
        for cy in [-1, 0, 1, 2] {
            var halo = world::neighborhood(map, world::section_slot(map, 0, cy, 0)); verify(halo);
        }
    }
    print("headless occlusion: ok");
}
