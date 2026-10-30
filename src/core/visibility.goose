// Conservative AABB/frustum rejection in SDL_GPU clip space (depth 0..w).
// Rows are ordinary vectors, so this module does not import a graphics API.
import vec;
namespace visibility;

fn intersects(rows: float4[4], lo: float3, hi: float3) -> bool {
    let planes: float4[6] = [rows[3] + rows[0], rows[3] - rows[0],
                             rows[3] + rows[1], rows[3] - rows[1], rows[2], rows[3] - rows[2]];
    for p in planes {
        let corner = float3 { if p.x >= 0.0 { hi.x } else { lo.x },
                              if p.y >= 0.0 { hi.y } else { lo.y },
                              if p.z >= 0.0 { hi.z } else { lo.z } };
        if p.x * corner.x + p.y * corner.y + p.z * corner.z + p.w < 0.0 { return false; }
    }
    return true;
}
