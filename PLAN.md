# Description
Target file: zombies_test4.html
General information: zombies_test4.md

# Issues

- [ ] Inverted WASD and aim controls: The player should move forward with W, and backwards with S. Moving the mouse forward should make the player look upwards, and pulling the mouse back should make the player look down.
- [x] Floor collisions: Player falls through the floor occasionally, sometimes after moving through WASD. Additionally, bullets seem to travel through the floor as well. This should not happen.
- [ ] Air jump fix: The player should be able to jump once while on a platform, and once in the air. Currently, the first jump can happen whether or not the player is on a platform.
- [ ] Performance checks: The game lags occasionally. Think of places where performance might be addressed, and attempt fixes

# Discussion

### Floor collisions fix (completed)

Three root causes were identified and fixed:

1. **Side-push ran unconditionally** — The horizontal side-push code executed even after a vertical top/bottom collision was already resolved. This could push the player sideways off the platform edge on the very frame they landed. Fixed by wrapping the side-push in an `else` block so it only runs when no vertical resolution was applied.

2. **Static collision tolerance too small** — The landing detection tolerance was a fixed `0.15` units. At larger frame times (up to 50ms), a falling entity could travel more than 0.15m in a single frame, tunneling past the platform surface before the check could catch it. Fixed by computing a dynamic tolerance based on the entity's actual vertical travel distance that frame (`tol = max(0.12, yTravel + 0.05)`).

3. **No swept collision detection** — The collision check only looked at the entity's final position each frame, not its trajectory. An entity starting above a platform could end up below it within one frame, missing the collision entirely. Fixed by saving the previous Y position and using it in the landing check: if the entity was above the surface at the start of the frame, it's treated as having landed on top regardless of whether the final position exceeded the tolerance.

4. **Projectile tunneling** — Player bullets travel at 65 m/s (~1m/frame at 60fps) and enemy bullets at 18-22 m/s, but collision was checked only at the final position. Thin platforms (0.5-0.6m thick) could be completely skipped. Fixed by sub-stepping projectile movement: the number of sub-steps is computed from `ceil(speed * dt / 0.25)`, ensuring each sub-step moves the projectile at most 0.25m. Collision is checked at every sub-step.
