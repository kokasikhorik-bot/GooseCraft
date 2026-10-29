import core from "../src/core";

fn main() {
    var chunk = world::Chunk {};
    assert(world::solid_count(chunk) == 0);
    // Every voxel has a distinct position, including all six boundaries.
    for y in 16 {
        for z in 16 {
            for x in 16 {
                assert(world::set(chunk, x, y, z, ((x + z + y) % 255 + 1) as u8));
            }
        }
    }
    assert(world::solid_count(chunk) == 4096);
    for y in 16 {
        for z in 16 {
            for x in 16 {
                assert(world::get(chunk, x, y, z) == ((x + z + y) % 255 + 1) as u8);
            }
        }
    }
    assert(!world::set(chunk, -1, 0, 0, 0));
    assert(!world::set(chunk, 0, -1, 0, 0));
    assert(!world::set(chunk, 0, 0, -1, 0));
    assert(!world::set(chunk, 16, 0, 0, 0));
    assert(!world::set(chunk, 0, 16, 0, 0));
    assert(!world::set(chunk, 0, 0, 16, 0));
    assert(world::solid_count(chunk) == 4096);
    assert(world::set(chunk, 15, 15, 15, 0));
    assert(world::get(chunk, 15, 15, 15) == 0);
    assert(world::solid_count(chunk) == 4095);
    var flat = world::flat_fixture();
    assert(world::solid_count(flat) == 256);
    assert(world::get(flat, 15, 0, 15) == 1);
    assert(world::get(flat, 0, 1, 0) == 0);
    var state = simulation::State {};
    assert(state.ticks == 0);
    for i in 100 { simulation::tick(state); }
    assert(state.ticks == 100);
    print("headless core: ok");
}
