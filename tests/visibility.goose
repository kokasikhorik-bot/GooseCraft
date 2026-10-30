import core from "../src/core";

fn main() {
    let identity: float4[4] = [float4 { 1.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 1.0, 0.0, 0.0 },
                               float4 { 0.0, 0.0, 1.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 1.0 }];
    assert(visibility::intersects(identity, float3 { -0.5, -0.5, 0.1 }, float3 { 0.5, 0.5, 0.9 }));
    assert(!visibility::intersects(identity, float3 { 2.0, -0.5, 0.1 }, float3 { 3.0, 0.5, 0.9 }));
    assert(!visibility::intersects(identity, float3 { -0.5, -0.5, -2.0 }, float3 { 0.5, 0.5, -1.0 }));
    assert(visibility::intersects(identity, float3 { 1.0, -0.5, 0.1 }, float3 { 2.0, 0.5, 0.9 }));
    let perspective: float4[4] = [float4 { 1.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 1.0, 0.0, 0.0 },
                                  float4 { 0.0, 0.0, -10.0 / 9.0, -10.0 / 9.0 }, float4 { 0.0, 0.0, -1.0, 0.0 }];
    assert(visibility::intersects(perspective, float3 { -0.5, -0.5, -4.0 }, float3 { 0.5, 0.5, -3.0 }));
    assert(!visibility::intersects(perspective, float3 { -0.5, -0.5, 3.0 }, float3 { 0.5, 0.5, 4.0 }));
    assert(!visibility::intersects(perspective, float3 { -0.5, -0.5, -0.9 }, float3 { 0.5, 0.5, -0.1 }));
    assert(!visibility::intersects(perspective, float3 { -0.5, -0.5, -13.0 }, float3 { 0.5, 0.5, -12.0 }));
    assert(visibility::intersects(perspective, float3 { -16.0, 0.0, -16.0 }, float3 { 16.0, 16.0, 16.0 }));
    print("headless visibility: ok");
}
