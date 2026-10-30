// Own test fixture, not Minecraft terrain or a Minecraft block registry.
namespace world;

struct Chunk { blocks: u8[4096] = [0; 4096] }

fn contains(x: i64, y: i64, z: i64) -> bool {
    x >= 0 && x < 16 && y >= 0 && y < 16 && z >= 0 && z < 16
}

fn index(x: i64, y: i64, z: i64) -> i64 {
    assert(contains(x, y, z));
    x + 16 * (z + 16 * y)
}

fn set(chunk: Chunk&, x: i64, y: i64, z: i64, value: u8) -> bool {
    if !contains(x, y, z) { return false; }
    chunk.blocks[index(x, y, z)] = value;
    return true;
}

fn get(chunk: Chunk&, x: i64, y: i64, z: i64) -> u8 {
    chunk.blocks[index(x, y, z)]
}

fn solid_count(chunk: Chunk&) -> i64 {
    var count: i64 = 0;
    for value in chunk.blocks { if value != 0 { count++; } }
    return count;
}

fn flat_fixture() -> Chunk {
    var chunk = Chunk {};
    for z in 16 {
        for x in 16 { assert(set(chunk, x, 0, z, 1)); }
    }
    return chunk;
}

fn demo_fixture() -> Chunk {
    var chunk = flat_fixture();
    for y in 1..5 { assert(set(chunk, 5, y, 5, 2)); }
    for y in 1..8 { assert(set(chunk, 10, y, 9, 2)); }
    return chunk;
}
