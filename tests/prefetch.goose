import os;
import core from "../src/core";
import core.prefetch;

fn receive(map: world::Paged&, state: prefetch::State&) {
    var result, got = qget<prefetch::Result>(5000); assert(got);
    prefetch::accept(map, state, result);
}
fn request(map: world::Paged&, state: prefetch::State&, at: i64) {
    assert(!state.busy);
    assert(qput(prefetch::Job { ticket: state.ticket + 1, at: at, index: map.index }));
    state.ticket++; state.submitted++; state.busy = true;
}
fn main() {
    let argv = args(); assert(argv.len == 2);
    let root = argv[1]; assert(pages::prepare_new(root));
    let lock = pages::lock(root); assert(lock != 0); defer pages::unlock(lock);
    assert(pages::create(root, 12345, 4));
    var map = world::Paged {}; assert(pages::open(root, map) && pages::ensure(root, map, 0, 0, 1));
    var state = prefetch::State {}; prefetch::start(root, state, 10.5, 13.5);
    defer prefetch::stop(state);
    state.target_x = 1; state.target_z = 0; state.radius = 2;
    let before = map;
    for i in 5 {
        prefetch::submit(map, state); assert(state.busy);
        let ticket = state.ticket; prefetch::submit(map, state); assert(ticket == state.ticket);
        receive(map, state); assert(map == before); // Worker never writes the live model.
    }
    assert(pages::ensure_cached(root, map, 1, 0, 1, state.cache));
    assert(state.cache.hits == 5 && state.cache.reads == 0 && map.peak == 25);
    let edited = world::slot(4, -2, 4);
    state.target_x = 2; request(map, state, edited);
    assert(pages::ensure(root, map, 2, 0, 1));
    assert(world::set(map, 64, 15, -32, 2) && pages::save(root, map));
    assert(pages::ensure(root, map, -2, 0, 1));
    receive(map, state);
    assert(state.cache.discarded == 1); // Old generation, even though slot is missing again.
    request(map, state, edited); receive(map, state);
    assert(pages::ensure_cached(root, map, 2, 0, 1, state.cache));
    assert(state.cache.hits == 6 && state.cache.reads > 0 && world::get(map, 64, 15, -32) == 2);
    assert(pages::ensure(root, map, -4, 0, 1));
    state.target_x = 4; request(map, state, edited); receive(map, state);
    assert(pages::ensure(root, map, 4, 0, 1));
    assert(world::set(map, 64, 15, -32, 1) && pages::ensure(root, map, -4, 0, 1));
    let hits = state.cache.hits;
    assert(pages::ensure_cached(root, map, 4, 0, 1, state.cache));
    assert(state.cache.hits == hits && world::get(map, 64, 15, -32) == 1); // Cached old contents rejected after commit.
    assert(pages::ensure(root, map, -4, 0, 1));
    let path = pages::page_path(root, map.index, edited, map.index.generations[edited]);
    var original: u8[4128] = [0; 4128]; assert(fileio::read_exact(path, original) == 1);
    assert(write_file_atomic(path, "corrupt"));
    for i in 8 { state.cache.entries[i].at = -1; }
    state.target_x = 4; request(map, state, edited); receive(map, state);
    assert(state.errors == 1);
    let intact = map;
    assert(!pages::ensure_cached(root, map, 4, 0, 1, state.cache) && map == intact);
    assert(write_file_atomic(path, original) && pages::ensure_cached(root, map, 4, 0, 1, state.cache));
    assert(world::get(map, 64, 15, -32) == 1);
    prefetch::stop(state);
    assert(state.worker == -1 && !state.busy && state.completed == state.submitted);
    for i in 3 {
        var restart = prefetch::State {};
        prefetch::start(root, restart, 0.0, 0.0, 20);
        request(map, restart, edited); prefetch::stop(restart); // Stop while a delayed job is pending.
        assert(!restart.busy && restart.submitted == restart.completed);
        let result, got = qpoll<prefetch::Result>(); assert(!got);
    }
    print("headless prefetch: ok");
}
