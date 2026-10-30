// Release-only CPU benchmark. No GPU, sleeping, network or external assets.
import os;
import std;
import core from "../src/core";

fn fixture(kind: i64) -> world::Chunk {
    if kind == 1 { return world::flat_fixture(); }
    if kind == 3 { return world::demo_fixture(); }
    var chunk = world::Chunk {};
    for y in 16 { for z in 16 { for x in 16 {
        if kind == 2 || (kind == 4 && y < 2 + (x * 3 + z * 5) % 9) ||
           (kind == 5 && (x + y + z) % 2 == 0) {
            world::set(chunk, x, y, z, if kind == 4 && y > 5 { 2 } else { 1 });
        }
    } } }
    return chunk;
}

fn measure(chunk: world::Chunk&, iterations: i64, greedy: bool) -> i64, i64, i64, i64 {
    var vertices: mesh::Vertex[>..] = [];
    var indices: u32[>..] = [];
    var checksum: i64 = 0;
    // Warm buffers and code before starting the monotonic timer.
    for i in 8 {
        vertices.clear(); indices.clear();
        if greedy { mesh::build(chunk, vertices, indices); }
        else { mesh::build_reference(chunk, vertices, indices); }
    }
    let start = clock_ns();
    for i in iterations {
        vertices.clear(); indices.clear();
        if greedy { mesh::build(chunk, vertices, indices); }
        else { mesh::build_reference(chunk, vertices, indices); }
        checksum += vertices.len + indices.len;
        if indices.len > 0 {
            checksum += indices[indices.len - 1];
            checksum += vertices[vertices.len - 1].color[0];
        }
    }
    let elapsed = clock_ns() - start;
    assert(elapsed > 0);
    return elapsed, vertices.len, indices.len, checksum;
}

fn main() {
    let argv = args();
    if argv.len != 3 || argv[1] != "--iterations" { exit(2); }
    let iterations, ok = parse_int(argv[2]);
    if !ok || iterations < 10 || iterations > 5000 { exit(2); }
    let names: const u8[:][6] = ["empty", "flat", "full", "demo", "terrain", "checker"];
    for kind in 6 {
        var chunk = fixture(kind);
        for sample in 7 {
            // Alternate order to limit a systematic warmup/CPU-frequency bias.
            let first_greedy = sample % 2 == 1;
            let a, av, ai, ac = measure(chunk, iterations, first_greedy);
            let b, bv, bi, bc = measure(chunk, iterations, !first_greedy);
            print("{\"scene\":\"", names[kind], "\",\"sample\":", sample,
                  ",\"iterations\":", iterations,
                  ",\"reference_ns\":", if first_greedy { b } else { a },
                  ",\"greedy_ns\":", if first_greedy { a } else { b },
                  ",\"reference_vertices\":", if first_greedy { bv } else { av },
                  ",\"greedy_vertices\":", if first_greedy { av } else { bv },
                  ",\"reference_indices\":", if first_greedy { bi } else { ai },
                  ",\"greedy_indices\":", if first_greedy { ai } else { bi },
                  ",\"checksum\":", ac + bc, "}");
        }
    }
}
