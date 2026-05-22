# Space Station Omega — Debug Thread 1

## Project Overview

A single-file 3D first-person shooter built with raw WebGL, custom math (Vec3, Quaternions, 4×4 matrices), a physics engine with AABB collisions, object pools, and an orbital space station level.

**File:** `zombies_test4.html` (~1264 lines)

---

## Architecture at a Glance

```
┌──────────────────────────────────────────────────────────────────┐
│                        GAME LOOP (60fps)                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  UPDATE (physics, AI, projectiles, particles)               │  │
│  │  ├── Player input → acceleration/deceleration → velocity     │  │
│  │  ├── Gravity, platform AABB collisions, wall sliding         │  │
│  │  ├── Enemy AI (patrol → chase → attack)                     │  │
│  │  └── Projectile vs. entity overlap checks                    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  RENDER (WebGL draw calls)                                  │  │
│  │  1. Build view matrix  (M4.lookAt from camera pos+quat)     │  │
│  │  2. Build proj matrix  (M4.perspective)                     │  │
│  │  3. For each object:                                         │  │
│  │     a. mdlMat = identity                                     │  │
│  │     b. M4.translate(mdlMat, mdlMat, pos)  ← in-place       │  │
│  │     c. M4.scale(mdlMat, mdlMat, size)    ← in-place       │  │
│  │     d. mvpMat = proj × view × mdlMat                        │  │
│  │     e. renderer.draw(mdlMat, mvpMat, color, emissive, cam)  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  HUD / MENUS (HTML overlays — independent of WebGL)         │  │
│  │  Health bar, kills, crosshair, minimap, boss health bar      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Math Module Design

The `M4` (4×4 matrix) module operates on `Float32Array(16)` buffers in column-major order. Three core operations:

```
M4.mul(o, a, b)    →  o = a × b          (matrix multiply)
M4.translate(o, m, x,y,z) → o = m × T(x,y,z)   (appends translation)
M4.scale(o, m, sx,sy,sz)  → o = m × S(sx,sy,sz) (appends scale)
```

The render loop chains these **in-place**:

```
mdlMat = M4.id()                              // [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
M4.translate(mdlMat, mdlMat, pos[0],...)      // mdlMat = I × T = T
M4.scale(mdlMat, mdlMat, size[0],...)         // mdlMat = T × S = final model matrix
```

When `o` and `a` are the same array (in-place call), the multiply must be careful not to overwrite source values before reading them.

---

## Bugs Found and Fixed

### Bug 1: `M4.lookAt` — Shared Mutable Temporaries → Degenerate View Matrix

**Symptom:** Camera produces a broken view matrix, but since Bug 4 also existed, this wasn't immediately isolatable.

**Root cause:** Three basis vectors (`forward`, `right`, `up`) were computed into shared temporary arrays `_t0` and `_t1`. By the time the third vector was computed, the first two pointed at the same memory:

```javascript
// BROKEN — all three vars alias _t0
const z = V.normalize(_t0, V.sub(_t1, eye, ctr));  // z === _t0
const x = V.normalize(_t0, V.cross(_t1, up, z));   // x === _t0 (same ref as z!)
const y = V.cross(_t0, z, x);                       // z === x → cross = [0,0,0]
```

**Fix:** Replaced with scalar-component math — no shared arrays, each basis vector computed independently:

```javascript
const z0 = eyex - ctr[0], z1 = eyey - ctr[1], z2 = eyez - ctr[2];
// normalize z
const fx = uy*fz2 - uz*fz1, fy = uz*fz0 - ux*fz2, fz = ux*fz1 - uy*fz0;
// normalize x
const fy0 = fz1*fz - fz2*fy, fy1 = fz2*fx - fz0*fz, fy2 = fz0*fy - fz1*fx;
// y = cross(z, x)
```

---

### Bug 2: `renderer.draw` — Per-Draw Float32Array Allocation

**Symptom:** Performance impact — not a correctness bug, but would cause GC pressure and frame drops.

**Root cause:** A new `Float32Array(9)` was allocated inside `draw()` for the 3×3 normal matrix — one allocation per object per frame (100+ objects × 60fps = 6000+ allocations/sec).

**Fix:** Moved the normal matrix buffer to the constructor as a reusable instance field:

```javascript
// Constructor: allocate once
this._nm = new Float32Array(9);

// draw(): mutate in-place
const nm = this._nm;
nm[0]=m[0]; nm[1]=m[1]; // ... etc.
```

---

### Bug 3: Minimap — Invisible Platforms

**Symptom:** Minimap canvas appeared blank/empty.

**Root cause:** Platform fill color `rgba(0, ${g}, 0, 0.5)` on background `rgba(0, 10, 0, 0.75)` had near-zero contrast — dark green on slightly darker green.

**Fix:** Changed to a dark navy background with height-mapped cyan/blue platform colors and bright colored enemy markers with white outlines.

---

### Bug 4: `M4.mul` — In-Place Source Corruption → Black Screen ⭐

**Symptom:** HUD, minimap, and crosshair render fine. Damage flash works. Player movement is reflected on the minimap. But the WebGL canvas is completely black — no platforms, enemies, stars, or projectiles visible.

**Root cause:** The matrix multiply zeros each output element *before* accumulating the dot product. When `o === a` (in-place call), this destroys source values that haven't been read yet.

**Concrete example with the identity matrix:**

```
mdlMat = [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1]  (identity)
T      = [1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  px, py, pz, 1]  (translate)

M4.mul(mdlMat, mdlMat, T)   ← o === a!
```

Inside `mul`, computing the (0,0) output element:

```
Step 1:  o[0] = 0          ← ZEROS OUT mdlMat[0] which was 1!
Step 2:  for k: o[0] += a[k*4+0] * b[0*4+k]
         k=0: o[0] += a[0] * b[0]  = 0 * 1 = 0   ← reads the zeroed value!
         k=1: o[0] += a[4] * b[1]  = 0 * 0 = 0
         k=2: o[0] += a[8] * b[2]  = 0 * 0 = 0
         k=3: o[0] += a[12]* b[3]  = 0 * 0 = 0
Result:  o[0] = 0          ← WRONG! Should be 1
```

The identity's `1` at position `[0]` is destroyed before it contributes to the dot product. This happens for **every diagonal element**. The result is an all-zeros matrix:

```
mdlMat becomes: [0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0]
```

Then scale on zeros is still zeros. The final MVP matrix is all zeros. Every vertex transforms to `(0, 0, 0, 0)` in clip space — `w = 0` means the perspective divide produces `NaN`, and all fragments are clipped away. **Nothing renders.**

**Why other things still worked:**

| Feature | Why it worked |
|---------|--------------|
| Minimap | Reads `player.pos`, `enemy.pos` directly from the physics simulation — not WebGL |
| HUD | HTML/CSS overlays — completely independent of WebGL rendering |
| Damage flash | CSS opacity animation on a div |
| Player movement | Physics runs correctly; only the render path is broken |
| Enemy AI | Runs in the update loop; only visual feedback is broken |
| Pointer lock / aiming | DOM-level pointer capture; not related to rendering |

**Fix:** Accumulate into a temporary array first, then copy to the output:

```javascript
mul: (o, a, b) => {
    const r = new Float32Array(16);
    for (let i = 0; i < 4; i++)
        for (let j = 0; j < 4; j++)
            for (let k = 0; k < 4; k++)
                r[i*4+j] += a[k*4+j] * b[i*4+k];
    for (let i = 0; i < 16; i++) o[i] = r[i];
    return o;
}
```

---

## Visual Summary: Why the Screen Was Black

```
                  BROKEN (before fix)                 FIXED (after fix)
                  ──────────────────────              ─────────────────
                  
  mdlMat = I      [1,0,0,0  ...]                      [1,0,0,0  ...]
                  ↓                                     ↓
  translate       o[0]=0 → reads a[0]=0                r[0]=a[0]*b[0]=1
  (in-place)      o[5]=0 → reads a[5]=0                r[5]=a[5]*b[5]=1
                  o[10]=0 → reads a[10]=0              r[10]=a[10]*b[10]=1
                  ↓                                     ↓
  mdlMat becomes  [0,0,0,0  ...]  ← ALL ZEROS         [1,0,0,0  ...] ← T
                  ↓                                     ↓
  scale           0 × sx = 0                           T × S = TS
                  ↓                                     ↓
  mvp = VP×mdl    VP × 0 = 0                           VP × TS = MVP
                  ↓                                     ↓
  vertex × MVP    (x,y,z,1) × 0 = (0,0,0,0)            proper clip coords
                  ↓                                     ↓
  perspective     0/0 = NaN → clipped                  proper NDC coords
  divide          ↓                                     ↓
                  NOTHING                               GEOMETRY VISIBLE
```

---

## Key Lesson

**Never write to `o` before finishing reads from `a` in an in-place operation.** Matrix multiply is a common culprit because it naturally decomposes into "zero output, then accumulate" — which works when `o !== a` but silently corrupts the result when `o === a`. The fix is either:

1. **Accumulate into a separate buffer, then copy** (what we did)
2. **Check if `o === a` and use a different algorithm** (e.g., compute in a safe order)
3. **Avoid in-place calls entirely** (less ergonomic for chaining)
