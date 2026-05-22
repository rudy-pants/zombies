# Description
Target file: zombies_test4.html
General information: zombies_test4.md

# Issues

- [x] WASD controls: The player should move to the left with A, and to the right with D. Currently, those controls are inverted.
- [x] Aim controls: Currently, the camera seems to rotate downward on it's own when the user isn't moving the mouse at all. Identify and resolve this issue.

# Discussion

## WASD Controls Inverted
The movement direction vector was being rotated by the yaw quaternion with incorrect local-axis signs. A was mapped to `md[0]--` (negative X) and D to `md[0]++` (positive X), but the yaw quaternion's rotation direction (built from `-dx` in the mouse handler) caused these local directions to map to the opposite world directions. Swapping the signs — A now uses `md[0]++` and D uses `md[0]--` — corrects the strafe direction so A moves left and D moves right relative to the player's facing direction.

## Camera Rotates Downward on Its Own
The root cause was a shared mutable temp array (`_t0`) used in two conflicting roles:
1. As a scratch buffer for `V.sub()` calls throughout `update()` (enemy AI, projectile hit detection, knockback calculations), where it stores arbitrary direction vectors.
2. As the forward-direction input vector in `Q.rotVec(fwd, full, fwd)` in `getLookDir()`, `render()`, and `renderMinimap()`.

Because `_t0` is overwritten by `V.sub()` during each frame's update phase, the value it holds when `render()` runs is stale data from the previous frame's math. If that stale vector had a non-zero Y component (common when enemies are above/below the player), the camera look direction would include an unintended vertical component, making the camera appear to drift or rotate downward. `getLookDir()` would also return wrong directions, causing projectiles to fire incorrectly.

**Fix:** Replaced `const fwd=_t0` with `const fwd=[0,0,1]` in `getLookDir()`, `render()`, and `renderMinimap()`, ensuring the forward vector starts as the canonical forward axis `[0,0,1]` before quaternion rotation, rather than inheriting stale values from unrelated calculations.
