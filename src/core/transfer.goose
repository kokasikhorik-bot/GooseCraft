// An opt-in deferred R transition. Main never reads a page in pump().
import .prefetch;
namespace transfer;

struct State {
    phase: i64 = 0, // 0 idle, 1 preflight, 2 admission, 3 failed (fail closed).
    x: i64 = 0, z: i64 = 0, radius: i64 = 0, prior_ticket: i64 = 0,
    wanted: bool[81] = [false; 81], checked: bool[81] = [false; 81],
    starts: i64 = 0, completed: i64 = 0, requests: i64 = 0,
    incoming: i64 = 0, validated: i64 = 0, admitted: i64 = 0, max_admitted: i64 = 0,
}
fn pending(state: State&) -> bool { state.phase == 1 || state.phase == 2 }
fn begin(map: world::Paged&, worker: prefetch::State&, state: State&, x: i64, z: i64, mesh_radius: i64) {
    assert(state.phase == 0 && worker.worker >= 0 && mesh_radius >= 1 && mesh_radius <= 2);
    state.phase = 1; state.starts++; state.prior_ticket = worker.ticket;
    state.x = clamp(x, -map.radius, map.radius); state.z = clamp(z, -map.radius, map.radius);
    state.radius = mesh_radius + 1; state.checked = [false; 81]; state.wanted = [false; 81];
    worker.target_x = state.x; worker.target_z = state.z; worker.radius = state.radius;
    for at in world::slots(map) {
        state.wanted[at] = world::active(map, at) && ((abs(world::chunk_x(map, at) - state.x) <= state.radius &&
            abs(world::chunk_z(map, at) - state.z) <= state.radius) || at == world::slot(0, 0, map.radius));
        if state.wanted[at] && map.locations[at] < 0 { state.incoming++; }
    }
    prepared::retain(worker.cache, map, state.wanted);
    for entry in worker.cache.entries {
        if entry.at >= 0 { state.checked[entry.at] = true; state.validated++; }
    }
}
fn begin(map: world::Map&, worker: prefetch::State&, state: State&, x: i64, z: i64, mesh_radius: i64) { abort("transfer requires a paged world"); }
fn begin(map: world::Tall&, worker: prefetch::State&, state: State&, x: i64, z: i64, mesh_radius: i64) { abort("transfer requires a paged world"); }

fn pump(root: const u8[:], map: world::Paged&, worker: prefetch::State&, state: State&) -> bool {
    assert(pending(state));
    if worker.busy {
        var result, got = qpoll<prefetch::Result>();
        if got {
            prefetch::finish(worker, result);
            let at = result.page.at;
            if state.wanted[at] && map.locations[at] < 0 && prepared::matches(result.page, map.index, at) && result.page.ok {
                if state.phase == 1 && !state.checked[at] { state.checked[at] = true; state.validated++; }
                var stored = false;
                for i in 8 {
                    if worker.cache.entries[i].at < 0 { worker.cache.entries[i] = result.page; stored = true; break; }
                }
                if !stored { worker.cache.discarded++; }
            } else {
                worker.cache.discarded++;
                // A stale speculative job may predate this transition. Retry it.
                if result.ticket > state.prior_ticket && state.wanted[at] && map.locations[at] < 0 {
                    state.phase = 3; return false;
                }
            }
        }
    }
    if state.phase == 1 {
        for at in world::slots(map) {
            if state.wanted[at] && map.locations[at] < 0 && !state.checked[at] {
                if !worker.busy { prefetch::request(map, worker, at); state.requests++; }
                return true;
            }
        }
        if !pages::shift(root, map, state.wanted) { state.phase = 3; return false; }
        state.phase = 2;
    }
    var admitted: i64 = 0;
    for i in 8 {
        if admitted >= 2 { break; }
        let at = worker.cache.entries[i].at;
        if at >= 0 {
            assert(state.wanted[at] && map.locations[at] < 0 && worker.cache.entries[i].ok &&
                prepared::matches(worker.cache.entries[i], map.index, at));
            pages::install(map, at, worker.cache.entries[i].chunk);
            worker.cache.entries[i].at = -1; admitted++; state.admitted++;
        }
    }
    state.max_admitted = max(state.max_admitted, admitted);
    for at in world::slots(map) {
        if !state.wanted[at] || map.locations[at] >= 0 { continue; }
        var staged = false; for entry in worker.cache.entries { staged = staged || entry.at == at; }
        if !staged && !worker.busy { prefetch::request(map, worker, at); state.requests++; }
        return true;
    }
    map.center_x = state.x; map.center_z = state.z; map.cpu_radius = state.radius;
    state.phase = 0; state.completed++;
    return true;
}
fn pump(root: const u8[:], map: world::Map&, worker: prefetch::State&, state: State&) -> bool { false }
fn pump(root: const u8[:], map: world::Tall&, worker: prefetch::State&, state: State&) -> bool { false }
