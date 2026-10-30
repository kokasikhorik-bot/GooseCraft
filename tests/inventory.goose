import core from "../src/core";

fn main() {
    var bag = inventory::State {};
    assert(inventory::material(bag) == 1 && !bag.opened);
    assert(inventory::select(bag, 8) && inventory::material(bag) == 0);
    let before = bag;
    for bad in [-1, 9, 9223372036854775807] { assert(!inventory::select(bag, bad) && bag == before); }
    assert(!inventory::click(bag, 9, false) && bag == before);
    inventory::toggle(bag); assert(bag.opened && inventory::click(bag, 10, false) && bag.held == 2);
    assert(inventory::click(bag, 8, false) && inventory::material(bag) == 2 && bag.held == 0);
    assert(inventory::click(bag, 0, false) && bag.slots[0] == 0 && bag.held == 1);
    assert(inventory::click(bag, 8, false) && bag.slots[8] == 1 && bag.held == 2); // Swap, not duplication.
    assert(inventory::click(bag, 2, false) && bag.slots[2] == 2 && bag.held == 0);
    assert(inventory::click(bag, 1, true) && bag.slots[1] == 0);
    assert(inventory::click(bag, 9, false) && inventory::click(bag, 10, true) && bag.held == 0);
    let intact = bag;
    for bad in [-1, 11, 9223372036854775807] { assert(!inventory::click(bag, bad, false) && bag == intact); }
    assert(inventory::click(bag, 9, false)); inventory::close(bag);
    assert(!bag.opened && bag.held == 0 && bag.slots == intact.slots);
    // UI hit bounds, gaps and a narrow viewport use the same Goose layout as HUD.
    for width in [320, 640, 1280] {
        for slot in 9 {
            let rect = inventory::slot_rect(width, 480, slot);
            assert(inventory::target(width, 480, rect.x, rect.y) == slot);
            assert(inventory::target(width, 480, (rect.x + rect.w), rect.y) == -1);
        }
        for item in 1..3 {
            let rect = inventory::palette_rect(width, 480, item);
            assert(inventory::target(width, 480, (rect.x + 1), (rect.y + 1)) == item + 8);
        }
    }
    // Selecting an empty slot cannot edit blocks or advance the world revision.
    var map = world::flat_fixture(); var player = player::State {};
    let hit = interaction::raycast(map, float3 { 8.5, 3.0, 8.5 }, float3 { 0.0, -1.0, 0.0 }, 6.0);
    assert(inventory::select(bag, 7)); let world_before = map;
    assert(!interaction::place(map, hit, player.position, inventory::material(bag)) && map == world_before);
    print("headless inventory: ok");
}
