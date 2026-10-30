import os;
import core from "../src/core";
import core.transfer;

fn complete(root: const u8[:], map: world::Paged&, worker: prefetch::State&, state: transfer::State&) -> bool {
    let deadline = clock_ns() + 5000000000;
    while transfer::pending(state) {
        assert(clock_ns() < deadline);
        let before = map; let admitted = state.admitted;
        let ok = transfer::pump(root, map, worker, state);
        if state.phase == 1 { assert(map == before); }
        assert(state.admitted - admitted <= 2 && map.peak <= 49);
        if !ok { return false; }
        if transfer::pending(state) { sleep_ms(1); }
    }
    return state.phase == 0;
}
fn main() {
    let argv = args(); assert(argv.len == 2); let root = argv[1];
    assert(pages::prepare_new(root)); let lock = pages::lock(root); assert(lock != 0); defer pages::unlock(lock);
    assert(pages::create(root, 12345, 4));
    var map = world::Paged {}; assert(pages::open(root, map) && pages::ensure(root, map, 4, 0, 1));
    assert(world::set(map, 64, 15, 0, 2)); // Dirty outgoing page must be committed.
    var worker = prefetch::State {}; prefetch::start(root, worker, 69.5, 13.5);
    defer prefetch::stop(worker);
    var state = transfer::State {};
    transfer::begin(map, worker, state, 0, 0, 1);
    assert(complete(root, map, worker, state));
    assert(state.incoming == 19 && state.validated == 19 && state.admitted == 19 && state.max_admitted == 2);
    assert(worker.cache.reads == 0 && map.commits == 1 && map.cpu_radius == 2 && map.center_x == 0);
    for at in world::slots(map) {
        if map.locations[at] >= 0 {
            var expected = terrain::chunk(12345, world::chunk_x(map, at), world::chunk_z(map, at));
            assert(map.chunks[map.locations[at]] == expected);
        }
    }
    // A second transition reuses the same bounded worker and state.
    transfer::begin(map, worker, state, 4, 0, 1);
    assert(complete(root, map, worker, state) && world::get(map, 64, 15, 0) == 2 && state.completed == 2);
    assert(worker.cache.reads == 0 && state.validated == state.incoming && state.admitted == state.incoming);
    // A speculative result from an older generation must be retried, not used.
    let old_at = world::slot(4, 0, 4);
    assert(pages::ensure(root, map, -4, 0, 1));
    prefetch::request(map, worker, old_at);
    assert(pages::ensure(root, map, 4, 0, 1) && world::set(map, 64, 15, 0, 1) && pages::save(root, map));
    assert(pages::ensure(root, map, -4, 0, 1));
    var stale = transfer::State {}; transfer::begin(map, worker, stale, 4, 0, 1);
    assert(complete(root, map, worker, stale) && world::get(map, 64, 15, 0) == 1);
    // A corrupt demanded page fails preflight before changing the live pool.
    assert(world::set(map, 64, 15, 0, 1) && pages::save(root, map));
    let at = world::slot(4, 0, 4); let path = pages::page_path(root, map.index, at, map.index.generations[at]);
    var bytes: u8[4128] = [0; 4128]; assert(fileio::read_exact(path, bytes) == 1);
    assert(pages::ensure(root, map, -4, 0, 1) && write_file_atomic(path, "bad"));
    var broken = transfer::State {}; transfer::begin(map, worker, broken, 4, 0, 1); let intact = map;
    assert(!complete(root, map, worker, broken) && broken.phase == 3 && map == intact);
    assert(write_file_atomic(path, bytes));
    // Failed dirty commit retains the live mapping and all unsaved blocks.
    assert(world::set(map, -64, 15, 0, 2));
    let outgoing = pages::page_path(root, map.index, world::slot(-4, 0, 4), map.index.serial + 1);
    assert(make_dir(outgoing)); var blocked = transfer::State {};
    transfer::begin(map, worker, blocked, 4, 0, 1); let dirty = map;
    assert(!complete(root, map, worker, blocked) && map == dirty && delete_dir(outgoing));
    // Closing after eviction is safe: dirty pages were committed first.
    var cancelled = transfer::State {}; transfer::begin(map, worker, cancelled, 4, 0, 1);
    let deadline = clock_ns() + 5000000000;
    while cancelled.phase == 1 {
        assert(clock_ns() < deadline && transfer::pump(root, map, worker, cancelled)); sleep_ms(1);
    }
    assert(cancelled.phase == 2 && cancelled.admitted <= 2);
    prefetch::stop(worker); assert(pages::save(root, map));
    var reopened = world::Paged {}; assert(pages::open(root, reopened) && pages::ensure(root, reopened, -4, 0, 1));
    assert(world::get(reopened, -64, 15, 0) == 2);
    assert(pages::ensure(root, reopened, 4, 0, 1) && world::get(reopened, 64, 15, 0) == 1);
    assert(worker.completed == worker.submitted && !worker.busy);
    // A demanded re-read can fail after eviction. Fail closed, then reopen.
    assert(pages::ensure(root, map, -4, 0, 1));
    prefetch::start(root, worker, -60.0, 13.5);
    var failed_read = transfer::State {}; transfer::begin(map, worker, failed_read, 4, 0, 1);
    while failed_read.phase == 1 {
        assert(transfer::pump(root, map, worker, failed_read)); sleep_ms(1);
    }
    assert(failed_read.phase == 2 && write_file_atomic(path, "bad"));
    assert(!complete(root, map, worker, failed_read) && failed_read.phase == 3);
    prefetch::stop(worker); assert(pages::save(root, map) && write_file_atomic(path, bytes));
    assert(pages::open(root, reopened) && pages::ensure(root, reopened, 4, 0, 1));
    assert(world::get(reopened, 64, 15, 0) == 1 && worker.cache.reads == 0);
    print("headless transfer: ok");
}
