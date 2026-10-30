// Main-thread staging: worker results and successful synchronous preflight reads.
import .world;
import .paged_world;
namespace prepared;

struct Page {
    at: i64 = -1, generation: u32 = 0, hash: u32 = 0, solids: i64 = 0,
    ok: bool = false, background: bool = false, chunk: world::Chunk = world::Chunk {},
}
struct None { reads: i64 = 0, read_ns: i64 = 0, hits: i64 = 0, disk_reads: i64 = 0 }
struct Cache {
    entries: Page[8] = [Page {}; 8],
    reads: i64 = 0, read_ns: i64 = 0, hits: i64 = 0, discarded: i64 = 0,
    disk_reads: i64 = 0,
    fallback_hits: i64 = 0,
}

fn matches(page: Page&, index: world::PageIndex&, at: i64) -> bool {
    page.at == at && page.generation == index.generations[at] &&
    page.hash == index.hashes[at] && page.solids == index.solids[at]
}
fn get(cache: None&, index: world::PageIndex&, at: i64, out: world::Chunk&) -> bool { false }
fn retain(cache: None&, map: world::Paged&, wanted: bool[81]&) {}
fn retain(cache: Cache&, map: world::Paged&, wanted: bool[81]&) {
    for i in 8 {
        let at = cache.entries[i].at;
        if at >= 0 && (!wanted[at] || map.locations[at] >= 0 ||
            !matches(cache.entries[i], map.index, at) || !cache.entries[i].ok) {
            cache.entries[i].at = -1; cache.discarded++;
        }
    }
}
fn remember(cache: None&, index: world::PageIndex&, at: i64, chunk: world::Chunk&) {}
fn remember(cache: Cache&, index: world::PageIndex&, at: i64, chunk: world::Chunk&) {
    // Never replace a worker result or grow the staging capacity on a teleport.
    for i in 8 {
        if cache.entries[i].at < 0 {
            cache.entries[i] = Page { at: at, generation: index.generations[at], hash: index.hashes[at],
                solids: index.solids[at], ok: true, chunk: chunk };
            return;
        }
    }
}
fn get(cache: Cache&, index: world::PageIndex&, at: i64, out: world::Chunk&) -> bool {
    for i in 8 {
        if matches(cache.entries[i], index, at) && cache.entries[i].ok {
            out = cache.entries[i].chunk; return true;
        }
    }
    return false;
}
fn consumed(cache: None&, index: world::PageIndex&, at: i64) {}
fn consumed(cache: Cache&, index: world::PageIndex&, at: i64) {
    for i in 8 {
        if matches(cache.entries[i], index, at) && cache.entries[i].ok {
            if cache.entries[i].background { cache.hits++; } else { cache.fallback_hits++; }
            cache.entries[i].at = -1; return;
        }
    }
}
