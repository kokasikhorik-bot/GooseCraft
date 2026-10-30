import core.core;
namespace chunks;

struct Cache {
    vertex: gfx::Buffer = gfx::Buffer { 0 },
    index: gfx::Buffer = gfx::Buffer { 0 },
    vertex_capacity: i64 = 0,
    index_capacity: i64 = 0,
    vertices: i64 = 0,
    indices: i64 = 0,
    allocations: i64 = 0,
    uploaded_bytes: i64 = 0,
    rebuilds: i64 = 0,
    patches: i64 = 0,
    split_patches: i64 = 0,
}

struct Stats { vertices: i64 = 0, indices: i64 = 0, capacity: i64 = 0,
               allocations: i64 = 0, uploaded_bytes: i64 = 0, patches: i64 = 0, split_patches: i64 = 0 }

fn reserve(buffer: gfx::Buffer&, capacity: i64&, required: i64, usage: i64, reference: bool) -> bool {
    if reference && buffer.id != 0 {
        gfx::release(buffer); buffer = gfx::Buffer { 0 }; capacity = 0;
    }
    if required <= capacity { return false; }
    if buffer.id != 0 { gfx::release(buffer); }
    capacity = if reference { required } else { 256 };
    while capacity < required { capacity *= 2; }
    buffer = gfx::buffer(usage, capacity, []);
    if buffer.id == 0 { abort(str("GPU allocation: ", gfx::error())); }
    return true;
}

fn rebuild(source: world::Halo&, vertices: mesh::Vertex[>..]&, indices: u32[>..]&,
           cache: Cache&, reference: bool, raw: bool) {
    vertices.clear(); indices.clear();
    if reference { mesh::build_reference(source, vertices, indices); }
    else { mesh::build(source, vertices, indices); }
    cache.patches = vertices.len / 4;
    cache.split_patches = if reference || raw { 0 } else { stitch::apply(vertices, indices) };
    let vb = bytes_of(vertices);
    let ib = bytes_of(indices);
    if reserve(cache.vertex, cache.vertex_capacity, vb.len, gfx::BUFFER_VERTEX, reference) { cache.allocations++; }
    if reserve(cache.index, cache.index_capacity, ib.len, gfx::BUFFER_INDEX, reference) { cache.allocations++; }
    if vb.len > 0 && !gfx::update_buffer(cache.vertex, vb) { abort(str("GPU vertex upload: ", gfx::error())); }
    if ib.len > 0 && !gfx::update_buffer(cache.index, ib) { abort(str("GPU index upload: ", gfx::error())); }
    cache.vertices = vertices.len; cache.indices = indices.len;
    cache.uploaded_bytes += vb.len + ib.len; cache.rebuilds++;
}

fn rebuild_dirty(map: world::Map&, caches: Cache[:], vertices: mesh::Vertex[>..]&, indices: u32[>..]&,
                 budget: i64, reference: bool, raw: bool) -> i64 {
    var done: i64 = 0;
    while done < budget {
        let at = world::pop_dirty(map);
        if at < 0 { break; }
        var source = world::neighborhood(map, at);
        rebuild(source, vertices, indices, caches[at], reference, raw);
        done++;
    }
    return done;
}

fn origin(at: i64) -> float3 { float3 { (at % 3 - 1) * 16, 0.0, (at / 3 - 1) * 16 } }

fn stats(caches: Cache[:]) -> Stats {
    var result = Stats {};
    for cache in caches {
        result.vertices += cache.vertices; result.indices += cache.indices;
        result.capacity += cache.vertex_capacity + cache.index_capacity;
        result.allocations += cache.allocations; result.uploaded_bytes += cache.uploaded_bytes;
        result.patches += cache.patches; result.split_patches += cache.split_patches;
    }
    return result;
}
