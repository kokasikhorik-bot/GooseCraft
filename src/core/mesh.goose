// CPU geometry only: the headless tests do not import gfx or SDL.
import vec;
import .world;
namespace mesh;

struct Vertex { position: float3, color: u8[4] }

fn solid(chunk: world::Chunk&, x: i64, y: i64, z: i64) -> bool {
    if !world::contains(x, y, z) { return false; }
    return world::get(chunk, x, y, z) != 0;
}

// Outward counterclockwise corners: +X, -X, +Y, -Y, +Z, -Z.
fn build(chunk: world::Chunk&, vertices: Vertex[>..]&, indices: u32[>..]&) {
    assert(vertices.len == 0 && indices.len == 0);
    let corners: u8[3][4][6] = [
        [[1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 0, 1]],
        [[0, 0, 1], [0, 1, 1], [0, 1, 0], [0, 0, 0]],
        [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]],
        [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]],
        [[1, 0, 1], [1, 1, 1], [0, 1, 1], [0, 0, 1]],
        [[0, 0, 0], [0, 1, 0], [1, 1, 0], [1, 0, 0]],
    ];
    let steps: i64[3][6] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0],
                            [0, -1, 0], [0, 0, 1], [0, 0, -1]];
    let light: f32[6] = [0.78, 0.58, 1.0, 0.42, 0.7, 0.62];
    for y in 16 {
        for z in 16 {
            for x in 16 {
                let id = world::get(chunk, x, y, z);
                if id == 0 { continue; }
                let tint: u8[3] = if id == 1 { [72, 165, 102] } else { [239, 174, 67] };
                for face in 6 {
                    let delta = steps[face];
                    if solid(chunk, x + delta[0], y + delta[1], z + delta[2]) { continue; }
                    let base = vertices.len as u32;
                    let color: u8[4] = [(tint[0] * light[face]) as! u8,
                                        (tint[1] * light[face]) as! u8,
                                        (tint[2] * light[face]) as! u8, 255];
                    for c in corners[face] {
                        vertices.push(Vertex { position: float3 { x + c[0],
                            y + c[1], z + c[2] }, color: color });
                    }
                    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
                }
            }
        }
    }
}
