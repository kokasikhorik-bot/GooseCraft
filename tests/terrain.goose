import core from "../src/core";
import .support.surface;
import math;

fn surfaces(map: world::Map&) {
    var expected: i64 = 0;
    let offsets: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    // Independent voxel-neighbor count includes outer walls and chunk seams.
    for z in world::lower(map)..world::upper(map) { for x in world::lower(map)..world::upper(map) { for y in 16 {
        if world::get(map, x, y, z) == 0 { continue; }
        for d in offsets { if world::get(map, x + d[0], y + d[1], z + d[2]) == 0 { expected++; } }
    } } }
    var actual: i64 = 0;
    for at in 9 {
        var halo = world::neighborhood(map, at);
        var reference: mesh::Vertex[>..] = [];
        var greedy: mesh::Vertex[>..] = [];
        var old_indices: u32[>..] = [];
        var new_indices: u32[>..] = [];
        mesh::build_reference(halo, reference, old_indices);
        mesh::build(halo, greedy, new_indices);
        var a: u32[24576] = [0; 24576];
        var b: u32[24576] = [0; 24576];
        let old_count = surface::coverage(halo, reference, old_indices, a);
        let new_count = surface::coverage(halo, greedy, new_indices, b);
        assert(a == b && old_count == new_count);
        actual += new_count;
    }
    assert(actual == expected);
}

fn generation(seed: u32) {
    var map = terrain::generate(seed);
    assert(map.revision == 0 && world::pending(map) == 9);
    // Reverse chunk order, then compare every byte; no mutable RNG state.
    for i in 9 {
        let at = 8 - i;
        let independent = terrain::chunk(seed, at % 3 - 1, at / 3 - 1);
        assert(independent.blocks == map.chunks[at].blocks);
    }
    var lowest: i64 = 16;
    var highest: i64 = 0;
    for z in -16..32 { for x in -16..32 {
        var filled: i64 = 0;
        for y in 16 { if world::get(map, x, y, z) != 0 { filled++; } }
        assert(filled >= 3 && filled <= 11);
        lowest = min(lowest, filled); highest = max(highest, filled);
        for y in filled { assert(world::get(map, x, y, z) == (if y == filled - 1 { 1 } else { 2 })); }
        // A surface can vary by one step at a seam, never a restarted cliff.
        if x < 31 { assert(abs(filled - terrain::height(seed, x + 1, z)) <= 2); }
        if z < 31 { assert(abs(filled - terrain::height(seed, x, z + 1)) <= 2); }
    } }
    assert(highest - lowest >= 3);
    var single = terrain::generate(seed, true);
    assert(world::pending(single) == 1 && single.chunks[4].blocks == map.chunks[4].blocks);
    for at in 9 { if at != 4 { assert(world::solid_count(single.chunks[at]) == 0); } }
    var bytes: u8[>..] = [];
    assert(storage::encode(map, bytes));
    var reopened = world::Map {};
    assert(storage::decode(bytes, reopened));
    for at in 9 { assert(map.chunks[at].blocks == reopened.chunks[at].blocks); }
    // Drop onto generated surfaces, including both sides of negative/positive seams.
    let locations: i64[2][6] = [[-15, -15], [-1, 8], [0, 8], [15, 13], [16, 13], [30, 30]];
    for p in locations {
        var state = player::State { position: float3 { p[0] + 0.5, 14.0, p[1] + 0.5 } };
        for tick in 240 { player::tick(map, state, player::Input {}); assert(!player::collides(map, state.position)); }
        assert(state.grounded && state.respawns == 0);
        assert(abs(state.position.y - terrain::height(seed, p[0], p[1])) < 0.001);
    }
    surfaces(map);
}

fn main() {
    // Fixed external vectors also check negative-coordinate Euclidean division.
    assert(terrain::height(12345, -17, -17) == 9);
    assert(terrain::height(12345, -1, -1) == 11);
    assert(terrain::height(12345, 0, 0) == 11);
    assert(terrain::height(12345, 31, 31) == 9);
    let seeds: u32[4] = [0, 1, 12345, 4294967295];
    for seed in seeds { generation(seed); }
    print("headless terrain: ok");
}
