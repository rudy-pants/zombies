# Description
Target file: zombies_test4.html
General information: zombies_test4.md

# Issues

- [x] Inverted WASD and aim controls: The player should move forward with W, and backwards with S. Moving the mouse forward should make the player look upwards, and pulling the mouse back should make the player look down.
- [x] Floor collisions: Player falls through the floor occasionally, sometimes after moving through WASD. Additionally, bullets seem to travel through the floor as well. This should not happen.
- [x] Air jump fix: The player should be able to jump once while on a platform, and once in the air. Currently, the first jump can happen whether or not the player is on a platform.
- [x] Performance checks: The game lags occasionally. Think of places where performance might be addressed, and attempt fixes

# Discussion

### Inverted WASD and aim controls fix (completed)

The root cause was a sign error in the mouse pitch calculation inside `onMouseM`. The code read `player.pitch -= dy` where `dy = e.movementY * MOUSE_SEN`. Since `movementY` is negative when the mouse moves toward the top of the screen (forward), subtracting a negative value made pitch positive. In the game's quaternion-based camera system (forward vector [0,0,1], right-handed coordinate system), a positive pitch angle rotates the camera **downward** — the opposite of what the player expects.

**Fix:** Changed `player.pitch -= dy` to `player.pitch += dy`. Now:
- Mouse forward (top of screen, `movementY < 0`) → pitch decreases (negative) → camera looks **up** ✓
- Mouse backward (bottom of screen, `movementY > 0`) → pitch increases (positive) → camera looks **down** ✓

WASD movement was verified correct: `KeyW` maps to +Z (forward), which is rotated by the yaw quaternion to produce proper camera-relative movement in all orientations.

### Floor collisions fix (completed)

Three root causes were identified and fixed:

1. **Side-push ran unconditionally** — The horizontal side-push code executed even after a vertical top/bottom collision was already resolved. This could push the player sideways off the platform edge on the very frame they landed. Fixed by wrapping the side-push in an `else` block so it only runs when no vertical resolution was applied.

2. **Static collision tolerance too small** — The landing detection tolerance was a fixed `0.15` units. At larger frame times (up to 50ms), a falling entity could travel more than 0.15m in a single frame, tunneling past the platform surface before the check could catch it. Fixed by computing a dynamic tolerance based on the entity's actual vertical travel distance that frame (`tol = max(0.12, yTravel + 0.05)`).

3. **No swept collision detection** — The collision check only looked at the entity's final position each frame, not its trajectory. An entity starting above a platform could end up below it within one frame, missing the collision entirely. Fixed by saving the previous Y position and using it in the landing check: if the entity was above the surface at the start of the frame, it's treated as having landed on top regardless of whether the final position exceeded the tolerance.

4. **Projectile tunneling** — Player bullets travel at 65 m/s (~1m/frame at 60fps) and enemy bullets at 18-22 m/s, but collision was checked only at the final position. Thin platforms (0.5-0.6m thick) could be completely skipped. Fixed by sub-stepping projectile movement: the number of sub-steps is computed from `ceil(speed * dt / 0.25)`, ensuring each sub-step moves the projectile at most 0.25m. Collision is checked at every sub-step.

### Air jump fix (completed)

The root cause was an incorrect initial value for `player.jumps` in the `mkPlayer()` factory. It was set to `2`, and the jump handler allowed jumping in mid-air whenever `e.ground` was false and `e.jumps > 0`. Since the player spawned with `jumps=2` and `ground=false`, the player could immediately press Space and perform a double-jump — even before ever touching a platform.

The game's spawn position (`y=2.5`) is above the starting platform surface (`y=0.3`), so the player falls for ~0.4s before landing. During that fall, `ground=false` but `jumps=2`, so pressing Space triggered the airborne branch (`e.jumps>0`) instead of requiring the grounded branch.

**Fix:** Changed `jumps:2` to `jumps:0` in `mkPlayer()`. Now the player must first land on a platform (which sets `ground=true` and `jumps=2` in the collision resolver) before any jump is possible. The flow is:
1. Player spawns in air → `jumps=0`, `ground=false` → **cannot jump** ✓
2. Player lands on platform → collision sets `ground=true`, `jumps=2` ✓
3. First jump (grounded) → uses `JUMP_F` (10), sets `jumps=1` ✓
4. Second jump (airborne) → uses `DOUBLE_F` (8), sets `jumps=0` ✓
5. Further jump attempts → `ground=false`, `jumps=0` → **blocked** ✓

### Performance optimization (completed)

Multiple sources of per-frame garbage collection pressure were identified in the render loop, which is called every frame (~60 times/sec). The game renders platforms (~30), enemies (up to 14 with 2 draw calls each), projectiles, particles, and **1000 stars** — each requiring matrix operations that previously allocated new `Float32Array` objects.

**Root causes and fixes:**

1. **`M4.mul()` allocated `new Float32Array(16)` every call** — This is the innermost operation of every draw call's model-view-projection matrix computation. With ~130+ draw calls per frame (30 platforms + 28 enemy draws + 1000 stars + projectiles + particles), this generated ~1300+ 128-byte allocations per frame. Fixed by using a pre-allocated `_m4tmp` buffer as the accumulator.

2. **`M4.translate()` and `M4.scale()` each allocated a temporary matrix** — Two more allocations per draw call (3 per entity total). Fixed by pre-allocating `_m4trans` and `_m4scale` and reusing them via direct index assignment instead of `new Float32Array([..])`.

3. **`mdlMat = M4.id()` leaked the old model matrix** — Each draw call in `render()` assigned `mdlMat = M4.id()`, which created a *new* `Float32Array(16)` via the default parameter. The old matrix became garbage. Fixed by calling `M4.id(mdlMat)` which mutates the existing buffer in-place via `o.fill(0)` + diagonal set.

4. **Quaternion allocations in `render()` camera setup** — Every frame allocated 3 arrays (`fwd`, `pq`, `full`) for camera direction computation. Fixed by reusing the shared temp arrays `_t0`, `_t1`, `_t2`.

5. **Same quaternion pattern in `getLookDir()` and `renderMinimap()`** — Each fired shot and minimap render allocated 3 arrays. Fixed similarly with temp buffer reuse.

**Impact:** Eliminated ~4000+ per-frame allocations (4 per draw call × ~1300 draw calls). This removes the primary GC pressure source, which was causing stop-the-world pauses and visible frame hitches.
