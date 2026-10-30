import os;
import core from "../src/core";

fn codecs() {
    var index = world::PageIndex {};
    var bytes: u8[1024] = [0; 1024]; pages::encode_index(index, bytes);
    var decoded = world::PageIndex {};
    assert(pages::decode_index(bytes, decoded) && decoded == index);
    for size in [0, 8, 16, 1003, 1023] { assert(!pages::decode_index(bytes[..size], decoded) && decoded == index); }
    bytes[1004] = 1; pages::put(bytes, 12, storage::checksum(bytes));
    assert(!pages::decode_index(bytes, decoded) && decoded == index);
    pages::encode_index(index, bytes); bytes[10] = 0; pages::put(bytes, 12, storage::checksum(bytes));
    assert(!pages::decode_index(bytes, decoded)); // Unknown seed requires explicit pages.
}

fn disk(base: const u8[:]) {
    let root = str(base, "/main"); assert(pages::prepare_new(root));
    let handle = pages::lock(root); assert(handle != 0); defer pages::unlock(handle);
    assert(pages::lock(root) == 0 && !pages::prepare_new(root));
    assert(pages::create(root, 12345, 4) && !pages::create(root, 1, 4));
    var map = world::Paged {}; assert(pages::open(root, map));
    assert(bytes_of(map.chunks).len == 49 * 4096 && world::solid_count(map) == 144444);
    for z in -4..5 { for x in -4..5 {
        assert(pages::ensure(root, map, x, z, 2));
        assert(map.resident <= 49 && map.peak <= 49);
        for at in world::slots(map) {
            let wanted = (abs(world::chunk_x(map, at) - x) <= 3 && abs(world::chunk_z(map, at) - z) <= 3) || at == world::slot(0, 0, 4);
            assert((map.locations[at] >= 0) == wanted);
            if wanted {
                var expected = terrain::chunk(12345, world::chunk_x(map, at), world::chunk_z(map, at));
                assert(map.chunks[map.locations[at]] == expected);
                assert(map.owners[map.locations[at]] == at);
            }
        }
    } }
    assert(pages::ensure(root, map, 0, 0, 1));
    assert(world::set(map, 16, 15, 0, 2));
    assert(pages::ensure(root, map, 4, 0, 1)); // Dirty eviction commits first.
    assert(map.commits == 1 && map.page_writes == 1 && map.locations[world::slot(1, 0, 4)] == -1);
    assert(pages::ensure(root, map, 0, 0, 1) && world::get(map, 16, 15, 0) == 2);
    assert(world::set(map, 16, 15, 0, 1) && world::set(map, 32, 15, 0, 2));
    var previous_header: u8[1024] = [0; 1024]; assert(fileio::read_exact(pages::index_path(root), previous_header) == 1);
    let blocked = pages::page_path(root, map.index, world::slot(2, 0, 4), map.index.serial + 1);
    assert(make_dir(blocked));
    let before = map;
    assert(!pages::ensure(root, map, 4, 0, 1) && map == before); // No dirty data discarded on failed write.
    var after_header: u8[1024] = [0; 1024]; assert(fileio::read_exact(pages::index_path(root), after_header) == 1);
    assert(after_header == previous_header && delete_dir(blocked));
    let index_backup = str(root, "/index.backup");
    assert(rename_file(pages::index_path(root), index_backup) && make_dir(pages::index_path(root)));
    assert(!pages::save(root, map) && map == before); // Publication failure preserves pending state.
    assert(delete_dir(pages::index_path(root)) && rename_file(index_backup, pages::index_path(root)));
    assert(fileio::read_exact(pages::index_path(root), after_header) == 1 && after_header == previous_header);
    assert(pages::ensure(root, map, 4, 0, 1));
    assert(map.index.serial == 2 && pages::ensure(root, map, 0, 0, 1));
    assert(world::get(map, 16, 15, 0) == 1 && world::get(map, 32, 15, 0) == 2);
    assert(pages::ensure(root, map, 4, 0, 1));
    let file = pages::page_path(root, map.index, world::slot(1, 0, 4), 2);
    var original: u8[4128] = [0; 4128]; assert(fileio::read_exact(file, original) == 1);
    var corrupt = original; corrupt[32] ^= 1;
    var output = world::Chunk {}; let untouched = output;
    assert(write_file_atomic(file, corrupt) && !pages::read_page(root, map.index, world::slot(1, 0, 4), output) && output == untouched);
    corrupt = original; corrupt[32] = 3; pages::put(corrupt, 12, storage::checksum(corrupt));
    var malicious_index = map.index; malicious_index.hashes[world::slot(1, 0, 4)] = pages::u32_at(corrupt, 12);
    assert(write_file_atomic(file, corrupt) && !pages::read_page(root, malicious_index, world::slot(1, 0, 4), output) && output == untouched);
    corrupt = original; pages::put(corrupt, 16, 2); pages::put(corrupt, 12, storage::checksum(corrupt));
    malicious_index.hashes[world::slot(1, 0, 4)] = pages::u32_at(corrupt, 12);
    assert(write_file_atomic(file, corrupt) && !pages::read_page(root, malicious_index, world::slot(1, 0, 4), output) && output == untouched);
    assert(write_file_atomic(file, "bad"));
    let intact = map;
    assert(!pages::ensure(root, map, 0, 0, 1) && map == intact); // Incoming preflight preserves the pool.
    assert(write_file_atomic(file, original) && pages::ensure(root, map, 0, 0, 1));
    var legacy = terrain::generate(12345, false, 4);
    world::set(legacy, 16, 15, 0, 1); world::set(legacy, 32, 15, 0, 2);
    for at in [world::slot(0, 0, 4), world::slot(1, 0, 4), world::slot(-1, -1, 4)] {
        var actual = world::neighborhood(map, at); var expected = world::neighborhood(legacy, at);
        assert(actual == expected); // Includes neighbors and negative coordinates.
    }
    var reopened = world::Paged {}; assert(pages::open(root, reopened) && pages::ensure(root, reopened, 0, 0, 2));
    assert(world::get(reopened, 16, 15, 0) == 1 && world::solid_count(reopened) == 144446);
    let probe = str(base, "/exact.bin"); assert(write_file(probe, "12345"));
    var four: u8[4] = [0; 4]; var five: u8[5] = [0; 5]; var six: u8[6] = [0; 6];
    assert(fileio::read_exact(probe, four) == 0 && fileio::read_exact(probe, five) == 1 && fileio::read_exact(probe, six) == 0);
}

fn imported(base: const u8[:]) {
    var source = terrain::generate(1); world::set(source, -1, 15, -1, 2);
    let path = str(base, "/source.gcw"); assert(storage::save(path, source));
    var before: u8[>..] = []; assert(read_file(path, before));
    let root = str(base, "/imported"); assert(pages::prepare_new(root));
    let handle = pages::lock(root); assert(handle != 0); defer pages::unlock(handle);
    assert(pages::import_world(path, root) && !pages::import_world(path, root));
    var map = world::Paged {}; assert(pages::open(root, map) && pages::ensure(root, map, 0, 0, 2));
    assert(map.index.generator == 0 && map.resident == 9 && world::solid_count(map) == world::solid_count(source));
    for at in 9 { assert(map.chunks[map.locations[at]] == source.chunks[at]); }
    var after: u8[>..] = []; assert(read_file(path, after) && after == before);
}

fn fallback(base: const u8[:]) {
    let root = str(base, "/fallback"); assert(pages::prepare_new(root));
    let handle = pages::lock(root); assert(handle != 0); defer pages::unlock(handle);
    assert(pages::create(root, 12345, 4));
    var map = world::Paged {}; assert(pages::open(root, map) && pages::ensure(root, map, 0, 0, 1));
    var cache = prepared::Cache {};
    // A cold five-page edge is read once, with no worker or extra page slots.
    assert(pages::ensure_cached(root, map, 1, 0, 1, cache));
    assert(cache.reads == 5 && cache.fallback_hits == 5 && cache.hits == 0);
    for entry in cache.entries { assert(entry.at < 0); }
    // A teleport needs fifteen incoming pages; only eight fit in staging.
    assert(pages::ensure_cached(root, map, -4, 0, 1, cache));
    assert(cache.reads == 27 && cache.fallback_hits == 13 && map.peak == 25);
    assert(pages::ensure_cached(root, map, 4, 0, 1, cache));
    assert(cache.reads == 49 && cache.fallback_hits == 21 && bytes_of(cache.entries).len < 33000);
    for at in world::slots(map) {
        if map.locations[at] >= 0 {
            var expected = terrain::chunk(12345, world::chunk_x(map, at), world::chunk_z(map, at));
            assert(map.chunks[map.locations[at]] == expected);
        }
    }
    // Fail late in preflight, after eight valid pages have been staged.
    assert(world::set(map, 64, 15, 32, 2) && pages::save(root, map));
    assert(pages::ensure_cached(root, map, -4, 0, 1, cache));
    let at = world::slot(4, 2, 4);
    let path = pages::page_path(root, map.index, at, map.index.generations[at]);
    var original: u8[4128] = [0; 4128]; assert(fileio::read_exact(path, original) == 1);
    assert(write_file_atomic(path, "bad"));
    let intact = map; let hits = cache.fallback_hits;
    assert(!pages::ensure_cached(root, map, 4, 0, 1, cache) && map == intact && cache.fallback_hits == hits);
    for entry in cache.entries { assert(entry.at >= 0 && entry.ok && !entry.background); }
    assert(write_file_atomic(path, original) && pages::ensure_cached(root, map, 4, 0, 1, cache));
    assert(world::get(map, 64, 15, 32) == 2 && cache.fallback_hits == hits + 8);
    // Failed dirty-eviction commit must retain the live model and staged pages.
    assert(world::set(map, 64, 15, 32, 1));
    let blocked = pages::page_path(root, map.index, at, map.index.serial + 1);
    assert(make_dir(blocked)); let pending = map;
    assert(!pages::ensure_cached(root, map, -4, 0, 1, cache) && map == pending);
    for entry in cache.entries { assert(entry.at >= 0 && entry.ok); }
    assert(delete_dir(blocked) && pages::ensure_cached(root, map, -4, 0, 1, cache));
    assert(pages::ensure_cached(root, map, 4, 0, 1, cache) && world::get(map, 64, 15, 32) == 1);
    // Prune a stale cache entry even when it belongs to the new target window.
    assert(pages::ensure(root, map, -4, 0, 1));
    var old = world::Chunk {}; assert(pages::read_page(root, map.index, at, old));
    prepared::remember(cache, map.index, at, old);
    assert(pages::ensure(root, map, 4, 0, 1) && world::set(map, 64, 15, 32, 2));
    assert(pages::ensure(root, map, -4, 0, 1));
    let discarded = cache.discarded;
    assert(pages::ensure_cached(root, map, 4, 0, 1, cache) && cache.discarded > discarded);
    assert(world::get(map, 64, 15, 32) == 2 && cache.hits == 0);
}

fn main() {
    let argv = args(); assert(argv.len == 2);
    codecs(); disk(argv[1]); imported(argv[1]); fallback(argv[1]); print("headless paging: ok");
}
