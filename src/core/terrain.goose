// GooseCraft terrain generator v1. Integer arithmetic only, no global RNG.
// Heights depend on absolute voxel coordinates, never generation order.
import std;
import .world;
namespace terrain;

let DEFAULT_SEED: u32 = 12345;

fn lattice(seed: u32, x: i64, z: i64) -> i64 {
    // Goose u32 arithmetic wraps; as! intentionally keeps coordinate low bits.
    var h: u32 = seed ^ ((x as! u32) * 0x9e3779b9) ^ ((z as! u32) * 0x85ebca6b);
    h ^= h >> 16; h *= 0x7feb352d;
    h ^= h >> 15; h *= 0x846ca68b;
    h ^= h >> 16;
    return h & 255;
}

fn smooth(t: i64) -> i64 { t * t * (768 - 2 * t) / 65536 }
fn blend(a: i64, b: i64, t: i64) -> i64 { (a * (256 - t) + b * t) / 256 }

fn noise(seed: u32, x: i64, z: i64, scale: i64) -> i64 {
    let cx = div_euclid(x, scale);
    let cz = div_euclid(z, scale);
    let tx = smooth((x % scale) * 256 / scale);
    let tz = smooth((z % scale) * 256 / scale);
    let a = blend(lattice(seed, cx, cz), lattice(seed, cx + 1, cz), tx);
    let b = blend(lattice(seed, cx, cz + 1), lattice(seed, cx + 1, cz + 1), tx);
    return blend(a, b, tz);
}

// Number of filled cells, 3..11. Headroom remains in the current 16-cell height.
fn height(seed: u32, x: i64, z: i64) -> i64 {
    3 + (noise(seed, x, z, 16) * 7 + noise(seed ^ 0xa511e9b3, x, z, 8) * 2) / 256
}

fn chunk(seed: u32, cx: i64, cz: i64) -> world::Chunk {
    // This version generates only the bounded world; avoid coordinate overflow.
    assert(cx >= -1 && cx <= 1 && cz >= -1 && cz <= 1);
    var result = world::Chunk {};
    for z in 16 { for x in 16 {
        let h = height(seed, cx * 16 + x, cz * 16 + z);
        for y in h { world::set(result, x, y, z, if y == h - 1 { 1 } else { 2 }); }
    } }
    return result;
}

fn generate(seed: u32, single: bool = false) -> world::Map {
    var result = world::Map { radius: if single { 0 } else { 1 } };
    for at in 9 {
        if world::active(result, at) { result.chunks[at] = chunk(seed, at % 3 - 1, at / 3 - 1); }
    }
    world::mark_all(result);
    return result;
}
