//
//  Shaders.metal
//  test-raytracing-swft
//
//  Created by Archie Maclean on 27/09/2025.
//

#include <metal_stdlib>

using namespace metal;
using namespace raytracing;

#define reflection_count (20000)

// This is a common, but not very good, random function.
float rand(int x){
    return 2.0f * fract(sin(x * 12.9898) * 43758.5453) - 1.0f;
}

kernel
void ray_trace_to_triangle(device float* out [[ buffer(0) ]],
                 primitive_acceleration_structure accelerationStructure [[ buffer(1) ]],
                 uint gid [[ thread_position_in_grid ]]) {
    ray ray;
//    ray.origin = float3(0, 0, gid / 250);
    ray.origin = float3(0, 0, 0);
    ray.direction = normalize(float3(rand(gid), rand(gid + 1), rand(gid + 2)));
    ray.max_distance = INFINITY;
    
    intersector<triangle_data> i;
    
    // Only accept closest intersection
    i.accept_any_intersection(false);
    
    // These make the intersection tests faster
    i.assume_geometry_type(geometry_type::triangle);
    i.force_opacity(forced_opacity::opaque);
    
    intersection_result<triangle_data> intersection_res;
    
    for (int n = 0; n < reflection_count; ++n) {
         intersection_res = i.intersect(ray, accelerationStructure);
    }
    
    if (intersection_res.type == intersection_type::none) {
        out[gid] = INFINITY;
    } else {
        out[gid] = intersection_res.distance;
    }
}
