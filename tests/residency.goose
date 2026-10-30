import core from "../src/core";

fn drain(map: world::Map&, state: residency::State&, budget: i64) -> i64 {
    var done: i64 = 0;
    while done < budget {
        let at = residency::next(map, state);
        if at < 0 { break; }
        residency::complete(map, state, at); done++;
    }
    return done;
}

fn movement() {
    var map = terrain::generate(12345, false, 4);
    let original = copy(map);
    var state = residency::State {};
    residency::update(map, state, 0, 0, 2);
    assert(state.desired == 25 && world::pending(map) == 25);
    assert(residency::next(map, state) == world::slot(0, 0, 4));
    assert(drain(map, state, 81) == 25 && state.resident == 25);
    assert(state.admissions == 25 && state.evictions == 0 && state.peak == 25);
    residency::update(map, state, 1, 0, 2);
    assert(state.resident == 20 && state.evictions == 5 && world::pending(map) == 5);
    assert(drain(map, state, 2) == 2 && state.resident == 22 && world::pending(map) == 3);
    // Change direction before the first admission queue drains.
    residency::update(map, state, -1, 0, 2);
    while world::pending(map) > 0 { assert(drain(map, state, 2) <= 2); }
    assert(state.resident == 25 && state.peak == 25);
    for z in -4..5 { for x in -4..5 {
        residency::update(map, state, x, z, 2);
        assert(state.desired <= 25 && state.resident <= 25);
        while world::pending(map) > 0 { assert(drain(map, state, 2) <= 2); }
        assert(state.resident == state.desired && state.peak == 25);
        for at in map.chunks.len {
            assert(state.ready[at] == (abs(world::chunk_x(map, at) - x) <= 2 && abs(world::chunk_z(map, at) - z) <= 2));
            assert(map.chunks[at] == original.chunks[at]);
        }
    } }
    assert(map.revision == 0);
    residency::update(map, state, 999, -999, 2);
    assert(state.center_x == 4 && state.center_z == -4 && state.desired == 9);
}

fn edits() {
    var map = world::region(false, true, 4);
    var state = residency::State {};
    residency::update(map, state, 0, 0, 1); drain(map, state, 81);
    // This change has no resident geometry yet, but must survive eviction,
    // save/load and subsequent mesh admission.
    assert(world::set(map, -64, 3, -64, 2));
    residency::update(map, state, 0, 0, 1);
    assert(world::pending(map) == 0 && map.revision == 1);
    residency::update(map, state, -4, -4, 1);
    assert(state.resident == 0 && state.desired == 4);
    assert(residency::next(map, state) == 0);
    var halo = world::neighborhood(map, 0);
    assert(world::get(halo, 0, 3, 0) == 2);
    drain(map, state, 81);
    assert(world::set(map, -49, 3, -49, 1) && world::pending(map) == 3);
    assert(drain(map, state, 2) == 2 && world::pending(map) == 1);
    drain(map, state, 2);
    var data: u8[>..] = []; assert(storage::encode(map, data));
    var loaded = world::Map {}; assert(storage::decode(data, loaded));
    assert(world::get(loaded, -64, 3, -64) == 2 && world::get(loaded, -49, 3, -49) == 1);
    residency::update(map, state, 0, 0, 1); drain(map, state, 81);
    residency::update(map, state, -4, -4, 1); drain(map, state, 81);
    assert(world::get(map, -64, 3, -64) == 2 && map.revision == 2);
}

fn modes() {
    for single in [false, true] {
        var map = terrain::generate(1, single);
        var state = residency::State {};
        residency::update(map, state, 0, 0, 0);
        assert(drain(map, state, 81) == world::count(map));
        assert(state.resident == world::count(map));
        residency::update(map, state, -1, -1, 0);
        assert(drain(map, state, 81) == 0 && state.evictions == 0);
    }
}

fn main() { movement(); edits(); modes(); print("headless residency: ok"); }
