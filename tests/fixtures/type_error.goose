// The harness must see the real compiler reject this deliberately bad program.
fn main() {
    let bad: i64 = "not an integer";
    print(bad);
}
