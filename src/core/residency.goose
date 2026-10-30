// GPU residency policy only. CPU blocks and save state are never evicted.
import .world;
namespace residency;

struct State {
    wanted: bool[324] = [false; 324], ready: bool[324] = [false; 324],
    center_x: i64 = 0, center_z: i64 = 0, radius: i64 = 0, initialized: bool = false,
    desired: i64 = 0, resident: i64 = 0, peak: i64 = 0,
    admissions: i64 = 0, evictions: i64 = 0, shifts: i64 = 0,
}

fn includes<T>(map: T&, cx: i64, cz: i64, radius: i64, at: i64) -> bool {
    world::active(map, at) && (radius == 0 ||
        (abs(world::chunk_x(map, at) - cx) <= radius && abs(world::chunk_z(map, at) - cz) <= radius))
}

fn update<T>(map: T&, state: State&, cx: i64, cz: i64, radius: i64) {
    assert(radius >= 0 && radius <= 4);
    let x = clamp(cx, -map.radius, map.radius);
    let z = clamp(cz, -map.radius, map.radius);
    if state.initialized && (state.center_x != x || state.center_z != z) { state.shifts++; }
    state.center_x = x; state.center_z = z; state.radius = radius; state.initialized = true;
    state.desired = 0;
    for at in world::slots(map) {
        let wanted = includes(map, x, z, radius, at);
        if wanted { state.desired++; }
        if state.ready[at] && !wanted {
            state.ready[at] = false; state.resident--; state.evictions++;
        }
        // No GPU geometry exists outside the set. Admission always rebuilds
        // from current CPU blocks, including edits made while nonresident.
        if !wanted { map.dirty[at] = false; }
        else if !state.ready[at] { map.dirty[at] = true; }
        state.wanted[at] = wanted;
    }
}

fn next<T>(map: T&, state: State&) -> i64 {
    var best: i64 = -1; var score: i64 = 1000000;
    for at in world::slots(map) {
        if !state.wanted[at] || !map.dirty[at] { continue; }
        let dx = abs(world::chunk_x(map, at) - state.center_x);
        let dz = abs(world::chunk_z(map, at) - state.center_z);
        let priority = if state.radius == 0 { at } else { max(dx, dz) * 100 + dx + dz };
        if priority < score { score = priority; best = at; }
    }
    return best;
}

fn complete<T>(map: T&, state: State&, at: i64) {
    assert(state.wanted[at] && map.dirty[at]);
    if !state.ready[at] {
        state.ready[at] = true; state.resident++; state.admissions++;
        state.peak = max(state.peak, state.resident);
    }
    map.dirty[at] = false;
}
