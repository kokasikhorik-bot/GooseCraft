// Version 3 directory store: immutable chunk pages + atomic index publication.
import os;
import .world;
import .paged_world;
import .terrain;
import .storage;
import .fileio;
import .prepared;
namespace pages;

// Diagnostic only. Copied into the worker by Goose at spawn, never shared.
var diagnostic_delay_ms: i64 = 0;

fn u32_at(data: const u8[:], at: i64) -> u32 {
    var n: u32 = 0; for i in 4 { n |= (data[at + i] as u32) << (8 * i); } return n;
}
fn put(data: u8[:], at: i64, n: u32) { for i in 4 { data[at + i] = (n >> (8 * i)) as! u8; } }
fn active(index: world::PageIndex&, at: i64) -> bool {
    at < world::pool_count(index.radius) && (index.radius != 0 || at == 4)
}
fn cx(index: world::PageIndex&, at: i64) -> i64 { at % world::width(index.radius) - max(index.radius, 1) }
fn cz(index: world::PageIndex&, at: i64) -> i64 { at / world::width(index.radius) - max(index.radius, 1) }
fn index_path(root: const u8[:]) -> u8[>..] { str(root, "/index.gci") }
fn page_path(root: const u8[:], index: world::PageIndex&, at: i64, serial: u32) -> u8[>..] {
    str(root, "/chunk_", cx(index, at), "_", cz(index, at), "_", serial, ".gcp")
}
fn lock(root: const u8[:]) -> u64 { fileio::lock(str(root, "/world.lock")) }
fn unlock(handle: u64) { assert(fileio::unlock(handle) == 1); }
fn prepare_new(root: const u8[:]) -> bool {
    if root.len == 0 || file_exists(root) || is_dir(root) { return false; }
    return storage::parent_directories(str(root, "/world.lock"));
}

fn encode_index(index: world::PageIndex&, out: u8[1024]&) {
    out = [0; 1024]; for i in 8 { out[i] = "GOOSEIDX"[i]; }
    out[8] = 3; out[9] = index.radius as u8; out[10] = index.generator as u8;
    put(out, 16, index.seed); put(out, 20, index.serial);
    put(out, 24, (if index.radius == 0 { 1 } else { world::pool_count(index.radius) }) as u32);
    for at in 81 {
        put(out, 32 + at * 12, index.generations[at]);
        put(out, 36 + at * 12, index.hashes[at]);
        put(out, 40 + at * 12, index.solids[at] as u32);
    }
    put(out, 12, storage::checksum(out));
}
fn decode_index(data: const u8[:], index: world::PageIndex&) -> bool {
    if data.len != 1024 || data[..8] != "GOOSEIDX" || data[8] != 3 || data[9] > 4 ||
       data[10] > 1 || data[11] != 0 || u32_at(data, 28) != 0 || u32_at(data, 12) != storage::checksum(data) { return false; }
    for i in 1004..1024 { if data[i] != 0 { return false; } }
    var next = world::PageIndex { radius: data[9], generator: data[10], seed: u32_at(data, 16), serial: u32_at(data, 20) };
    if next.serial > 2147483647 || (next.generator == 0 && next.seed != 0) ||
       u32_at(data, 24) != (if next.radius == 0 { 1 } else { world::pool_count(next.radius) }) { return false; }
    for at in 81 {
        let gen = u32_at(data, 32 + at * 12); let hash = u32_at(data, 36 + at * 12);
        let count = u32_at(data, 40 + at * 12);
        if gen > next.serial || count > 4096 { return false; }
        if !active(next, at) { if gen != 0 || hash != 0 || count != 0 { return false; } }
        else if gen == 0 && (next.generator == 0 || hash != 0) { return false; }
        next.generations[at] = gen; next.hashes[at] = hash; next.solids[at] = count;
    }
    index = next; return true;
}

fn encode_page(index: world::PageIndex&, at: i64, serial: u32, chunk: world::Chunk&, out: u8[4128]&) {
    out = [0; 4128]; for i in 8 { out[i] = "GOOSEPG3"[i]; }
    out[8] = 3; put(out, 16, cx(index, at) as! u32); put(out, 20, cz(index, at) as! u32);
    put(out, 24, serial); put(out, 28, world::solid_count(chunk) as u32);
    for i in 4096 { assert(chunk.blocks[i] <= 2); out[32 + i] = chunk.blocks[i]; }
    put(out, 12, storage::checksum(out));
}
fn read_page(root: const u8[:], index: world::PageIndex&, at: i64, chunk: world::Chunk&) -> bool {
    if diagnostic_delay_ms > 0 { sleep_ms(diagnostic_delay_ms); }
    assert(active(index, at));
    if index.generations[at] == 0 {
        if index.generator != 1 { return false; }
        var next = terrain::chunk(index.seed, cx(index, at), cz(index, at));
        if world::solid_count(next) != index.solids[at] { return false; }
        chunk = next; return true;
    }
    var bytes: u8[4128] = [0; 4128];
    if fileio::read_exact(page_path(root, index, at, index.generations[at]), bytes) != 1 { return false; }
    if bytes[..8] != "GOOSEPG3" || bytes[8] != 3 || bytes[9] != 0 || bytes[10] != 0 || bytes[11] != 0 ||
       u32_at(bytes, 12) != index.hashes[at] || u32_at(bytes, 12) != storage::checksum(bytes) ||
       u32_at(bytes, 16) != (cx(index, at) as! u32) || u32_at(bytes, 20) != (cz(index, at) as! u32) ||
       u32_at(bytes, 24) != index.generations[at] || u32_at(bytes, 28) != index.solids[at] { return false; }
    var next = world::Chunk {};
    for i in 4096 { if bytes[32 + i] > 2 { return false; } next.blocks[i] = bytes[32 + i]; }
    if world::solid_count(next) != index.solids[at] { return false; }
    chunk = next; return true;
}

// Caller holds the world lock from before open/create to after the last save.
fn create(root: const u8[:], seed: u32, radius: i64) -> bool {
    if radius < 1 || radius > 4 || file_exists(index_path(root)) { return false; }
    var index = world::PageIndex { radius: radius, seed: seed };
    for at in world::pool_count(radius) {
        var chunk = terrain::chunk(seed, cx(index, at), cz(index, at));
        index.solids[at] = world::solid_count(chunk);
    }
    var bytes: u8[1024] = [0; 1024]; encode_index(index, bytes);
    return write_file_atomic(index_path(root), bytes);
}
fn open(root: const u8[:], map: world::Paged&) -> bool {
    var bytes: u8[1024] = [0; 1024]; var index = world::PageIndex {};
    if fileio::read_exact(index_path(root), bytes) != 1 || !decode_index(bytes, index) { return false; }
    map.index = index; map.radius = index.radius; map.revision = 0;
    map.locations = [-1; 81]; map.owners = [-1; 49]; map.changed = [false; 81]; map.dirty = [false; 81];
    map.resident = 0; map.peak = 0; map.reads = 0; map.generated = 0;
    map.evictions = 0; map.commits = 0; map.page_writes = 0; map.center_x = 100; map.center_z = 100; map.cpu_radius = 0;
    return true;
}
fn save(root: const u8[:], map: world::Paged&) -> bool {
    var dirty = false; for flag in map.changed { dirty = dirty || flag; }
    if !dirty { return true; }
    if map.index.serial >= 2147483647 { return false; }
    var next = map.index; next.serial++;
    var bytes: u8[4128] = [0; 4128]; var written: i64 = 0;
    for at in world::slots(map) {
        if !map.changed[at] { continue; }
        let pool = map.locations[at]; assert(pool >= 0);
        encode_page(next, at, next.serial, map.chunks[pool], bytes);
        if !write_file_atomic(page_path(root, next, at, next.serial), bytes) { return false; }
        next.generations[at] = next.serial; next.hashes[at] = u32_at(bytes, 12); written++;
    }
    var header: u8[1024] = [0; 1024]; encode_index(next, header);
    if !write_file_atomic(index_path(root), header) { return false; }
    map.index = next; map.changed = [false; 81]; map.commits++; map.page_writes += written;
    return true;
}
fn save(path: const u8[:], map: world::Map&) -> bool { storage::save(path, map) }

fn read_cached<T>(root: const u8[:], map: world::Paged&, at: i64, out: world::Chunk&, cache: T&) -> bool {
    if prepared::get(cache, map.index, at, out) { return true; }
    if map.index.generations[at] != 0 { cache.disk_reads++; }
    let begin = clock_ns(); let ok = read_page(root, map.index, at, out);
    cache.reads++; cache.read_ns += clock_ns() - begin;
    return ok;
}

fn ensure_cached<T>(root: const u8[:], map: world::Paged&, cx: i64, cz: i64, mesh_radius: i64, cache: T&) -> bool {
    assert(mesh_radius >= 1 && mesh_radius <= 2);
    let x = clamp(cx, -map.radius, map.radius); let z = clamp(cz, -map.radius, map.radius);
    let radius = mesh_radius + 1;
    if map.center_x == x && map.center_z == z && map.cpu_radius == radius { return true; }
    var wanted: bool[81] = [false; 81]; var flush = false;
    var scratch = world::Chunk {};
    for at in world::slots(map) {
        wanted[at] = world::active(map, at) && ((abs(world::chunk_x(map, at) - x) <= radius && abs(world::chunk_z(map, at) - z) <= radius) || at == world::slot(0, 0, map.radius));
        if wanted[at] && map.locations[at] < 0 && !read_cached(root, map, at, scratch, cache) { return false; }
        if !wanted[at] && map.changed[at] { flush = true; }
    }
    if flush && !save(root, map) { return false; }
    for at in world::slots(map) {
        if wanted[at] || map.locations[at] < 0 { continue; }
        let pool = map.locations[at]; map.owners[pool] = -1; map.locations[at] = -1;
        map.resident--; map.evictions++; map.dirty[at] = false;
    }
    for at in world::slots(map) {
        if !wanted[at] || map.locations[at] >= 0 { continue; }
        var pool: i64 = 0; while pool < 49 && map.owners[pool] >= 0 { pool++; } assert(pool < 49);
        if !read_cached(root, map, at, scratch, cache) { return false; } // Fail closed after preflight.
        map.chunks[pool] = scratch; map.owners[pool] = at; map.locations[at] = pool; map.dirty[at] = true;
        map.resident++; map.peak = max(map.peak, map.resident);
        if map.index.generations[at] == 0 { map.generated++; } else { map.reads++; }
        prepared::consumed(cache, map.index, at);
    }
    map.center_x = x; map.center_z = z; map.cpu_radius = radius;
    return true;
}
fn ensure_cached<T>(path: const u8[:], map: world::Map&, cx: i64, cz: i64, mesh_radius: i64, cache: T&) -> bool { true }
fn ensure(root: const u8[:], map: world::Paged&, cx: i64, cz: i64, mesh_radius: i64) -> bool {
    var cache = prepared::None {}; return ensure_cached(root, map, cx, cz, mesh_radius, cache);
}
fn ensure(path: const u8[:], map: world::Map&, cx: i64, cz: i64, mesh_radius: i64) -> bool { true }

fn import_world(source: const u8[:], root: const u8[:]) -> bool {
    if file_exists(index_path(root)) { return false; }
    var raw: u8[331792] = [0; 331792]; let length = fileio::read_bounded(source, raw);
    if length < 0 { return false; }
    var map = world::Map {}; if !storage::decode(raw[..length], map) { return false; }
    var index = world::PageIndex { radius: map.radius, generator: 0, seed: 0, serial: 1 };
    var bytes: u8[4128] = [0; 4128];
    for at in map.chunks.len {
        if !world::active(map, at) { continue; }
        encode_page(index, at, 1, map.chunks[at], bytes);
        if !write_file_atomic(page_path(root, index, at, 1), bytes) { return false; }
        index.generations[at] = 1; index.hashes[at] = u32_at(bytes, 12); index.solids[at] = world::solid_count(map.chunks[at]);
    }
    var header: u8[1024] = [0; 1024]; encode_index(index, header);
    return write_file_atomic(index_path(root), header);
}

fn export_world(root: const u8[:], destination: const u8[:]) -> bool {
    if file_exists(destination) || is_dir(destination) { return false; }
    var paged = world::Paged {}; if !open(root, paged) { return false; }
    var map = world::create(paged.radius);
    for at in world::slots(paged) {
        if world::active(paged, at) && !read_page(root, paged.index, at, map.chunks[at]) { return false; }
    }
    return storage::save(destination, map);
}

fn format(map: world::Map&) -> i64 { storage::version(map) }
fn format(map: world::Paged&) -> i64 { 3 }
struct Stats { resident: i64 = 0, peak: i64 = 0, evictions: i64 = 0, commits: i64 = 0, writes: i64 = 0, loads: i64 = 0, generated: i64 = 0 }
fn stats(map: world::Map&) -> Stats { Stats { resident: world::count(map), peak: world::count(map) } }
fn stats(map: world::Paged&) -> Stats { Stats { map.resident, map.peak, map.evictions, map.commits, map.page_writes, map.reads, map.generated } }
fn report(map: world::Map&) -> u8[>..] {
    str(",\"paged\":false,\"cpu_resident_chunks\":", world::count(map),
        ",\"cpu_peak_chunks\":", world::count(map), ",\"cpu_evictions\":0,\"page_commits\":0,\"page_writes\":0,\"page_loads\":0,\"chunk_generations\":0")
}
fn report(map: world::Paged&) -> u8[>..] {
    str(",\"paged\":true,\"cpu_resident_chunks\":", map.resident, ",\"cpu_peak_chunks\":", map.peak,
        ",\"cpu_evictions\":", map.evictions, ",\"page_commits\":", map.commits,
        ",\"page_writes\":", map.page_writes, ",\"page_loads\":", map.reads, ",\"chunk_generations\":", map.generated)
}
