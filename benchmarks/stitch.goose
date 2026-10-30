// Native-only cost of reference, raw greedy, and greedy + edge stitching.
import os;
import std;
import core from "../src/core";

fn fixture(kind: i64) -> world::Map {
    if kind == 4 { return terrain::generate(terrain::DEFAULT_SEED); }
    var result = world::Map { radius: 0 };
    if kind == 1 { result.chunks[4] = world::flat_fixture(); }
    if kind == 3 { result.chunks[4] = world::demo_fixture(); }
    if kind == 2 || kind == 5 {
        for y in 16 { for z in 16 { for x in 16 {
            if kind == 2 || (x + y + z) % 2 == 0 { world::set(result.chunks[4], x, y, z, 1); }
        } } }
    }
    return result;
}

fn make(halo: world::Halo&, mode: i64, vertices: mesh::Vertex[>..]&, indices: u32[>..]&) {
    vertices.clear(); indices.clear();
    if mode == 0 { mesh::build_reference(halo, vertices, indices); }
    else { mesh::build(halo, vertices, indices); if mode == 2 { stitch::apply(vertices, indices); } }
}

fn measure(halos: world::Halo[:], iterations: i64, mode: i64) -> i64, i64, i64, i64 {
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    for warmup in 8 { for at in halos.len { make(halos[at], mode, vertices, indices); } }
    var vertex_count: i64 = 0; var index_count: i64 = 0; var checksum: i64 = 0;
    let start = clock_ns();
    for sample in iterations {
        vertex_count = 0; index_count = 0;
        for at in halos.len {
            make(halos[at], mode, vertices, indices);
            vertex_count += vertices.len; index_count += indices.len;
            checksum += vertices.len + indices.len;
            if indices.len != 0 { checksum += indices[indices.len - 1] + vertices[vertices.len - 1].color[0]; }
        }
    }
    let elapsed = clock_ns() - start;
    return elapsed, vertex_count, index_count, checksum;
}

fn main() {
    let argv = args();
    if argv.len != 3 || argv[1] != "--iterations" { exit(2); }
    let iterations, ok = parse_int(argv[2]);
    if !ok || iterations < 10 || iterations > 5000 { exit(2); }
    let scenes: const u8[:][6] = ["empty", "flat", "full", "demo", "terrain-region", "checker"];
    let modes: const u8[:][3] = ["reference", "raw-greedy", "stitched"];
    for kind in 6 {
        var map = fixture(kind);
        var halos: world::Halo[9] = [world::Halo {}; 9];
        var count: i64 = 0;
        for at in 9 { if world::active(map, at) { halos[count] = world::neighborhood(map, at); count++; } }
        for sample in 7 { for order in 3 {
            let mode = (sample + order) % 3;
            let ns, vertices, indices, checksum = measure(halos[..count], iterations, mode);
            print("{\"scene\":\"", scenes[kind], "\",\"mode\":\"", modes[mode],
                  "\",\"sample\":", sample, ",\"iterations\":", iterations, ",\"chunks\":", count,
                  ",\"ns\":", ns, ",\"vertices\":", vertices, ",\"indices\":", indices,
                  ",\"checksum\":", checksum, "}");
        } }
    }
}
