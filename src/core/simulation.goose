// Deterministic bootstrap state; no claim of Minecraft ticking parity.
namespace simulation;

struct State { ticks: i64 = 0 }

fn tick(state: State&) { state.ticks++; }
