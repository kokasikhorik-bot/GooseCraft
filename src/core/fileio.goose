// Small system boundary, no world-format or gameplay logic in C.
namespace fileio;
extern fn read_exact(path: const u8[:], out: u8[:]) -> i32 = "gc_read_exact";
extern fn read_bounded(path: const u8[:], out: u8[:]) -> i64 = "gc_read_bounded";
extern fn lock(path: const u8[:]) -> u64 = "gc_world_lock";
extern fn unlock(handle: u64) -> i32 = "gc_world_unlock";
