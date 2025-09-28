#  Ray Tracing Initial Test

The aim of the initial test was to ensure that I could use the ray tracing library for a basic task.

Initial test setup:
- Generate $N_T$ triangles with vertices randomly within (-100, 100)
- Each ray starts at the origin and has a random angle (probably not uniform, it just samples in -1-1 in 3D and then normalises).
- For each ray, calculate its intersection with the all of triangles, $N_R$ times.

25,000 rays, 5,000 triangles, 40,000 "reflections" (intersection tests) = 84 seconds (12,000,000 intersections per second).
20,000 rays, 3,000 triangles, 20,000 "reflections" (intersection tests) = 21 seconds (19,000,000 intersections per second).

The performance appears to increase significantly when the number of triangles that the ray intersects with decreases:

- If the z component of the ray start is scaled between 0 and 100 (so that rays with ID ~25000 mostly miss all triangles), the first setup yields 56 seconds (18,000,000 intersections per second) and the second 15 seconds (28,000,000 intersections per second).

This is without BVH/other optimisations. There's likely much more I could be doing in terms of declaring bits of memory as read-only/etc. to improve performance.

Metal API provides:
- Acceleration structures for splitting up data into boxes (BVH), so that entire boxes can be skipped - this will probably help a lot
- Instancing - potentially less useful for audio? Instancing multiple identical objects is faster than loading each separately

Using `accept_any_intersection(true)` (which needs only to find *an* intersection, not the closest one) reduces the time to around 5 seconds - much faster. This is probably not very useful though. Could it be useful in ISM methods?

Optimisation: https://www.youtube.com/watch?v=qPo-KpyKEXU
