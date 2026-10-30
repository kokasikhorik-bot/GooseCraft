// Native-only Goose worker. No mutable world, GPU or file lock crosses threads.
import os;
import math;
import .pages;
import .prepared;
namespace prefetch;

struct Path { bytes: u8[4096] = [0; 4096], length: i64 = 0 }
struct Job { stop: bool = false, ticket: i64 = 0, at: i64 = 0, index: world::PageIndex = world::PageIndex {} }
struct Result { ticket: i64 = 0, elapsed_ns: i64 = 0, page: prepared::Page = prepared::Page {} }
struct State {
    cache: prepared::Cache = prepared::Cache {},
    worker: i64 = -1, busy: bool = false, ticket: i64 = 0,
    target_x: i64 = 0, target_z: i64 = 0, radius: i64 = 0,
    last_x: f32 = 0.0, last_z: f32 = 0.0,
    submitted: i64 = 0, completed: i64 = 0, errors: i64 = 0,
    worker_ns: i64 = 0, join_ns: i64 = 0,
    disk_reads: i64 = 0,
}

thread_fn worker(path: Path, delay_ms: i64) {
    while true {
        var job = qget<Job>();
        if job.stop { break; }
        if delay_ms > 0 { sleep_ms(delay_ms); }
        let begin = clock_ns();
        var result = Result { ticket: job.ticket,
            page: prepared::Page { at: job.at, generation: job.index.generations[job.at],
                hash: job.index.hashes[job.at], solids: job.index.solids[job.at], background: true } };
        result.page.ok = pages::read_page(path.bytes[..path.length], job.index, job.at, result.page.chunk);
        result.elapsed_ns = clock_ns() - begin;
        assert(qput(result)); // At most one outstanding job, result queue limit 1.
    }
}

fn start(root: const u8[:], state: State&, x: f32, z: f32, delay_ms: i64 = 0) {
    assert(root.len > 0 && root.len < 4096 && state.worker < 0 && !state.busy);
    qlimit<Job>(1); qlimit<Result>(1);
    var path = Path { length: root.len }; for i in root.len { path.bytes[i] = root[i]; }
    state.last_x = x; state.last_z = z;
    state.target_x = world::chunk_coord(floor(x) as i64); state.target_z = world::chunk_coord(floor(z) as i64);
    let local_x = x - state.target_x * 16; let local_z = z - state.target_z * 16;
    if min(local_x, 16.0 - local_x) < min(local_z, 16.0 - local_z) {
        state.target_x += if local_x >= 8.0 { 1 } else { -1 };
    } else { state.target_z += if local_z >= 8.0 { 1 } else { -1 }; }
    state.worker = thread_spawn(worker, path, delay_ms);
}
fn wanted(map: world::Paged&, state: State&, at: i64) -> bool {
    world::active(map, at) && abs(world::chunk_x(map, at) - state.target_x) <= state.radius &&
        abs(world::chunk_z(map, at) - state.target_z) <= state.radius
}
fn finish(state: State&, result: Result&) {
    assert(state.busy && result.ticket == state.ticket);
    state.busy = false; state.completed++; state.worker_ns += result.elapsed_ns;
    if result.page.generation != 0 { state.disk_reads++; }
    if !result.page.ok { state.errors++; }
}
fn accept(map: world::Paged&, state: State&, result: Result&) {
    finish(state, result);
    let at = result.page.at;
    if !prepared::matches(result.page, map.index, at) || map.locations[at] >= 0 || !wanted(map, state, at) {
        state.cache.discarded++; return;
    }
    for i in 8 {
        if state.cache.entries[i].at < 0 { state.cache.entries[i] = result.page; return; }
    }
    state.cache.discarded++;
}
fn request(map: world::Paged&, state: State&, at: i64) {
    assert(!state.busy && state.worker >= 0 && world::active(map, at));
    assert(qput(Job { ticket: state.ticket + 1, at: at, index: map.index }));
    state.ticket++; state.submitted++; state.busy = true;
}
fn collect(map: world::Paged&, state: State&) {
    if !state.busy { return; }
    var result, got = qpoll<Result>();
    if got { accept(map, state, result); }
}
fn collect(map: world::Map&, state: State&) {}
fn collect(map: world::Tall&, state: State&) {}

fn submit(map: world::Paged&, state: State&) {
    if state.busy || state.worker < 0 { return; }
    for at in world::slots(map) {
        if map.locations[at] >= 0 || !wanted(map, state, at) { continue; }
        var present = false; var free = false;
        for i in 8 { present = present || state.cache.entries[i].at == at; free = free || state.cache.entries[i].at < 0; }
        if present { continue; } if !free { return; }
        let job = Job { ticket: state.ticket + 1, at: at, index: map.index };
        assert(qput(job)); state.ticket++; state.submitted++; state.busy = true; return;
    }
}
fn predict(map: world::Paged&, state: State&, x: f32, z: f32, mesh_radius: i64) {
    let cx = world::chunk_coord(floor(x) as i64); let cz = world::chunk_coord(floor(z) as i64);
    let dx = x - state.last_x; let dz = z - state.last_z;
    state.last_x = x; state.last_z = z; state.radius = mesh_radius + 1;
    // One leading axis, at most seven incoming pages. A teleport uses fallback.
    if max(abs(dx), abs(dz)) > 0.00001 && max(abs(dx), abs(dz)) < 8.0 {
        state.target_x = cx; state.target_z = cz;
        if abs(dx) >= abs(dz) { state.target_x += if dx > 0.0 { 1 } else { -1 }; }
        else { state.target_z += if dz > 0.0 { 1 } else { -1 }; }
    }
    else if max(abs(dx), abs(dz)) >= 8.0 { state.target_x = cx; state.target_z = cz; }
    state.target_x = clamp(state.target_x, -map.radius, map.radius);
    state.target_z = clamp(state.target_z, -map.radius, map.radius);
    for i in 8 {
        let at = state.cache.entries[i].at;
        if at >= 0 && (!wanted(map, state, at) || map.locations[at] >= 0 || !prepared::matches(state.cache.entries[i], map.index, at)) {
            state.cache.entries[i].at = -1; state.cache.discarded++;
        }
    }
    submit(map, state);
}
fn predict(map: world::Map&, state: State&, x: f32, z: f32, mesh_radius: i64) {}
fn predict(map: world::Tall&, state: State&, x: f32, z: f32, mesh_radius: i64) {}

fn stop(state: State&) {
    if state.worker < 0 { return; }
    let begin = clock_ns();
    if state.busy {
        let result = qget<Result>(); assert(result.ticket == state.ticket);
        state.completed++; state.worker_ns += result.elapsed_ns;
        if result.page.generation != 0 { state.disk_reads++; }
        if !result.page.ok { state.errors++; }
        state.cache.discarded++; state.busy = false;
    }
    assert(qput(Job { stop: true })); assert(thread_wait(state.worker)); state.worker = -1;
    state.join_ns += clock_ns() - begin;
}
fn shutdown(states: State[:]) { if states.len > 0 { stop(states[0]); } }

struct Stats {
    enabled: bool = false, submitted: i64 = 0, completed: i64 = 0, hits: i64 = 0,
    discarded: i64 = 0, errors: i64 = 0, worker_ns: i64 = 0, join_ns: i64 = 0,
    reads: i64 = 0, read_ns: i64 = 0, staging_bytes: i64 = 0,
    request_bytes: i64 = 0, result_bytes: i64 = 0,
    main_disk_reads: i64 = 0, worker_disk_reads: i64 = 0,
    fallback_hits: i64 = 0,
}
fn stats(states: State[:], synchronous: prepared::None&) -> Stats {
    if states.len == 0 { return Stats { reads: synchronous.reads, read_ns: synchronous.read_ns, main_disk_reads: synchronous.disk_reads }; }
    let s = states[0];
    return Stats { true, s.submitted, s.completed, s.cache.hits, s.cache.discarded, s.errors,
        s.worker_ns, s.join_ns, s.cache.reads, s.cache.read_ns, bytes_of(s.cache.entries).len,
        bytes_of([Job {}]).len, bytes_of([Result {}]).len, s.cache.disk_reads, s.disk_reads, s.cache.fallback_hits };
}
fn report(s: Stats) -> u8[>..] {
    str(",\"async_paging\":", s.enabled, ",\"prefetch_submitted\":", s.submitted,
        ",\"prefetch_completed\":", s.completed, ",\"prefetch_hits\":", s.hits,
        ",\"fallback_reuses\":", s.fallback_hits,
        ",\"prefetch_discarded\":", s.discarded, ",\"prefetch_errors\":", s.errors,
        ",\"prefetch_worker_ns\":", s.worker_ns, ",\"prefetch_join_ns\":", s.join_ns,
        ",\"main_page_reads\":", s.reads, ",\"main_page_read_ns\":", s.read_ns,
        ",\"prefetch_staging_bytes\":", s.staging_bytes, ",\"prefetch_request_bytes\":", s.request_bytes,
        ",\"prefetch_result_bytes\":", s.result_bytes, ",\"prefetch_queue_limit\":", if s.enabled { 1 } else { 0 },
        ",\"main_disk_page_reads\":", s.main_disk_reads, ",\"worker_disk_page_reads\":", s.worker_disk_reads)
}
