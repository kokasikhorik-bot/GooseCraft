// Opt-in wall-clock samples; no graphics dependency or allocation per record.
import std;
import os;
import .storage;
namespace profiling;

let CAPACITY: i64 = 1024;
struct Sample {
    frame: i64 = 0, wall_ns: i64 = 0, pump_ns: i64 = 0, game_ns: i64 = 0,
    mesh_ns: i64 = 0, save_ns: i64 = 0, submit_ns: i64 = 0,
    rebuilt: i64 = 0, draw_calls: i64 = 0, uploaded_bytes: i64 = 0, paused: i64 = 0, save_calls: i64 = 0,
}
struct Log {
    samples: Sample[1024] = [Sample {}; 1024],
    warmup: i64 = 30, seen: i64 = 0, count: i64 = 0, cursor: i64 = 0,
}
struct Summary {
    count: i64 = 0, min_ns: i64 = 0, p50_ns: i64 = 0, p95_ns: i64 = 0,
    p99_ns: i64 = 0, max_ns: i64 = 0, mean_ns: i64 = 0,
}
struct Context {
    driver: const u8[:] = "headless", offscreen: bool = false, replay: bool = false,
    reference: bool = false, raw: bool = false,
    startup_ns: i64 = 0, initial_mesh_ns: i64 = 0, tail_flush_ns: i64 = 0,
    loop_session_ns: i64 = 0, collector_ns_total: i64 = 0,
    exit_readback_ns: i64 = 0, exit_save_ns: i64 = 0, readback: bool = false,
    world_block_capacity_bytes: i64 = 0, active_world_block_bytes: i64 = 0,
    mesh_bytes: i64 = 0, mesh_capacity_bytes: i64 = 0, mesh_buffer_creations: i64 = 0,
    overlay_buffer_capacity_bytes: i64 = 0, overlay_buffer_creations: i64 = 0,
    world_radius: i64 = -1, world_chunks: i64 = 0, world_format: i64 = 0,
    mesh_radius: i64 = 0, resident_chunks: i64 = 0, peak_resident_chunks: i64 = 0,
    mesh_evictions: i64 = 0, initial_meshes: i64 = 0, initial_uploaded_bytes: i64 = 0,
    peak_mesh_capacity_bytes: i64 = 0,
    cpu_resident_chunks: i64 = 0, cpu_peak_chunks: i64 = 0, cpu_evictions: i64 = 0,
    page_commits: i64 = 0, page_writes: i64 = 0, page_loads: i64 = 0,
    async_paging: bool = false, prefetch_hits: i64 = 0, main_page_reads: i64 = 0,
    main_page_read_ns: i64 = 0, prefetch_worker_ns: i64 = 0, prefetch_join_ns: i64 = 0,
    prefetch_staging_bytes: i64 = 0,
    diagnostic_page_delay_ms: i64 = 0, diagnostic_worker_delay_ms: i64 = 0,
    main_disk_page_reads: i64 = 0, worker_disk_page_reads: i64 = 0,
    fallback_reuses: i64 = 0,
    deferred_respawn: bool = false, loading_frames: i64 = 0,
    transfer_starts: i64 = 0, transfer_completed: i64 = 0, transfer_requests: i64 = 0,
    transfer_incoming: i64 = 0, transfer_validated: i64 = 0, transfer_admitted: i64 = 0,
    transfer_max_admitted: i64 = 0, transfer_phase: i64 = 0,
    inventory_frames: i64 = 0, inventory_opens: i64 = 0, inventory_open: bool = false,
    selected_slot: i64 = 1, selected_material: i64 = 1,
    world_min_y: i64 = 0, world_max_y_exclusive: i64 = 16, sectioned: bool = false,
    ambient_occlusion: bool = false,
    textures: bool = false,
}

fn value(s: Sample, metric: i64) -> i64 {
    if metric == 0 { return s.wall_ns; }
    if metric == 1 { return s.pump_ns; }
    if metric == 2 { return s.game_ns; }
    if metric == 3 { return s.mesh_ns; }
    if metric == 4 { return s.save_ns; }
    assert(metric == 5); return s.submit_ns;
}

fn record(log: Log&, s: Sample) -> bool {
    assert(log.warmup >= 0);
    if s.frame != log.seen || s.wall_ns < 0 || s.rebuilt < 0 || s.draw_calls < 0 ||
       s.uploaded_bytes < 0 || s.paused < 0 || s.paused > 1 || s.save_calls < 0 || s.save_calls > 1 { return false; }
    var remaining = s.wall_ns;
    // Subtraction also rejects invalid totals without overflowing a sum.
    for metric in 1..6 {
        let part = value(s, metric);
        if part < 0 || part > remaining { return false; }
        remaining -= part;
    }
    if remaining != 0 { return false; }
    if log.seen >= log.warmup {
        log.samples[log.cursor] = s;
        log.cursor = (log.cursor + 1) % CAPACITY;
        log.count = min(log.count + 1, CAPACITY);
    }
    log.seen++;
    return true;
}

fn sample(log: Log&, index: i64) -> Sample {
    assert(index >= 0 && index < log.count);
    let first = if log.count == CAPACITY { log.cursor } else { 0 };
    return log.samples[(first + index) % CAPACITY];
}

fn percentile(sorted: i64[:], percent: i64) -> i64 {
    assert(percent >= 1 && percent <= 100);
    if sorted.len == 0 { return 0; }
    return sorted[(percent * sorted.len + 99) / 100 - 1]; // nearest rank
}

fn summarize(log: Log&, metric: i64) -> Summary {
    var sorted: i64[1024] = [0; 1024];
    var total: i64 = 0;
    for i in log.count { sorted[i] = value(sample(log, i), metric); total += sorted[i]; }
    sort(sorted[..log.count]);
    if log.count == 0 { return Summary {}; }
    return Summary { log.count, sorted[0], percentile(sorted[..log.count], 50),
        percentile(sorted[..log.count], 95), percentile(sorted[..log.count], 99),
        sorted[log.count - 1], total / log.count };
}

fn encode(log: Log&, context: Context, output: u8[>..]&) -> bool {
    assert(output.len == 0);
    // All JSON strings are controlled tags, never paths or arbitrary argv.
    if context.driver != "headless" && context.driver != "vulkan" && context.driver != "metal" &&
       context.driver != "direct3d12" && context.driver != "unknown" { return false; }
    let warmup = min(log.seen, log.warmup);
    output.append(str("{\"schema\":1,\"client_version\":\"0.14.0\",\"clock\":\"os.clock_ns\",",
        "\"scope\":\"CPU loop wall time; pump includes previous-frame submission/presentation; not GPU timestamps\",",
        "\"percentiles\":\"nearest-rank on retained samples\",\"driver\":\"", context.driver,
        "\",\"offscreen\":", context.offscreen, ",\"replay\":", context.replay,
        ",\"reference_renderer\":", context.reference, ",\"raw_greedy\":", context.raw,
        ",\"seen\":", log.seen, ",\"warmup_requested\":", log.warmup, ",\"warmup_discarded\":", warmup,
        ",\"retained\":", log.count, ",\"overwritten\":", log.seen - warmup - log.count,
        ",\"capacity\":", CAPACITY, ",\"sample_storage_bytes\":", bytes_of(log.samples).len));
    output.append(str(",\"startup_ns\":", context.startup_ns, ",\"initial_mesh_ns\":", context.initial_mesh_ns,
        ",\"loop_session_ns\":", context.loop_session_ns, ",\"collector_ns_total\":", context.collector_ns_total,
        ",\"tail_flush_ns\":", context.tail_flush_ns, ",\"exit_readback_ns\":", context.exit_readback_ns,
        ",\"exit_save_ns\":", context.exit_save_ns, ",\"readback_performed\":", context.readback,
        ",\"world_block_capacity_bytes\":", context.world_block_capacity_bytes,
        ",\"active_world_block_bytes\":", context.active_world_block_bytes,
        ",\"mesh_bytes\":", context.mesh_bytes, ",\"mesh_capacity_bytes\":", context.mesh_capacity_bytes,
        ",\"mesh_buffer_creations\":", context.mesh_buffer_creations,
        ",\"world_radius\":", context.world_radius, ",\"world_chunks\":", context.world_chunks,
        ",\"world_format\":", context.world_format,
        ",\"mesh_radius\":", context.mesh_radius, ",\"resident_chunks\":", context.resident_chunks,
        ",\"peak_resident_chunks\":", context.peak_resident_chunks, ",\"mesh_evictions\":", context.mesh_evictions,
        ",\"initial_meshes\":", context.initial_meshes, ",\"initial_uploaded_bytes\":", context.initial_uploaded_bytes,
        ",\"peak_mesh_capacity_bytes\":", context.peak_mesh_capacity_bytes,
        ",\"cpu_resident_chunks\":", context.cpu_resident_chunks, ",\"cpu_peak_chunks\":", context.cpu_peak_chunks,
        ",\"cpu_evictions\":", context.cpu_evictions, ",\"page_commits\":", context.page_commits,
        ",\"page_writes\":", context.page_writes, ",\"page_loads\":", context.page_loads,
        ",\"async_paging\":", context.async_paging, ",\"prefetch_hits\":", context.prefetch_hits,
        ",\"fallback_reuses\":", context.fallback_reuses,
        ",\"main_page_reads\":", context.main_page_reads, ",\"main_page_read_ns\":", context.main_page_read_ns,
        ",\"prefetch_worker_ns\":", context.prefetch_worker_ns, ",\"prefetch_join_ns\":", context.prefetch_join_ns,
        ",\"prefetch_staging_bytes\":", context.prefetch_staging_bytes,
        ",\"diagnostic_page_delay_ms\":", context.diagnostic_page_delay_ms,
        ",\"diagnostic_worker_delay_ms\":", context.diagnostic_worker_delay_ms,
        ",\"main_disk_page_reads\":", context.main_disk_page_reads,
        ",\"worker_disk_page_reads\":", context.worker_disk_page_reads));
    output.append(str(",\"deferred_respawn\":", context.deferred_respawn, ",\"loading_frames\":", context.loading_frames,
        ",\"logical_frames\":", log.seen - context.loading_frames, ",\"transfer_starts\":", context.transfer_starts,
        ",\"transfer_completed\":", context.transfer_completed, ",\"transfer_requests\":", context.transfer_requests,
        ",\"transfer_incoming\":", context.transfer_incoming, ",\"transfer_validated\":", context.transfer_validated,
        ",\"transfer_admitted\":", context.transfer_admitted, ",\"transfer_max_admitted\":", context.transfer_max_admitted,
        ",\"transfer_phase\":", context.transfer_phase,
        ",\"overlay_buffer_capacity_bytes\":", context.overlay_buffer_capacity_bytes,
        ",\"overlay_buffer_creations\":", context.overlay_buffer_creations, ","));
    output.append(str("\"inventory_frames\":", context.inventory_frames, ",\"inventory_opens\":", context.inventory_opens,
        ",\"inventory_open\":", context.inventory_open, ",\"selected_slot\":", context.selected_slot,
        ",\"selected_material\":", context.selected_material,
        ",\"world_min_y\":", context.world_min_y, ",\"world_max_y_exclusive\":", context.world_max_y_exclusive,
        ",\"sectioned\":", context.sectioned, ",\"ambient_occlusion\":", context.ambient_occlusion,
        ",\"textures\":", context.textures, ",\"vertex_stride\":", if context.textures { 20 } else { 16 },
        ",\"texture_payload_bytes\":", if context.textures { 4096 } else { 0 }, ","));
    output.append("\"memory_scope\":\"known block storage and requested GPU buffer bytes; excludes allocator, driver, RSS/VRAM totals\",\"summary\":{");
    let names: const u8[:][6] = ["wall_ns", "pump_ns", "game_ns", "mesh_ns", "save_ns", "submit_ns"];
    for metric in 6 {
        if metric != 0 { output.push(','); }
        let s = summarize(log, metric);
        output.append(str("\"", names[metric], "\":{\"count\":", s.count,
            ",\"min_ns\":", s.min_ns, ",\"p50_ns\":", s.p50_ns, ",\"p95_ns\":", s.p95_ns,
            ",\"p99_ns\":", s.p99_ns, ",\"max_ns\":", s.max_ns, ",\"mean_ns\":", s.mean_ns, "}"));
    }
    output.append("},\"columns\":[\"frame\",\"wall_ns\",\"pump_ns\",\"game_ns\",\"mesh_ns\",\"save_ns\",\"submit_ns\",\"rebuilt\",\"draw_calls\",\"uploaded_bytes\",\"paused\",\"save_calls\"],\"rows\":[");
    for i in log.count {
        if i != 0 { output.push(','); }
        let s = sample(log, i);
        output.append(str("[", s.frame, ",", s.wall_ns, ",", s.pump_ns, ",", s.game_ns, ",", s.mesh_ns,
            ",", s.save_ns, ",", s.submit_ns, ",", s.rebuilt, ",", s.draw_calls, ",", s.uploaded_bytes, ",", s.paused, ",", s.save_calls, "]"));
    }
    output.append("]}\n");
    return true;
}

fn save(path: const u8[:], log: Log&, context: Context) -> bool {
    if file_exists(path) || is_dir(path) { return false; }
    var data: u8[>..] = [];
    if !encode(log, context, data) || !storage::parent_directories(path) { return false; }
    return write_file_atomic(path, data);
}
