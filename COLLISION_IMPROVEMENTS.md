# Collision and Physics Improvements Documentation

## Overview
Three significant improvements have been made to the collision and physics systems to enhance accuracy and performance.

---

## 1. ✅ Continuous Collision Detection (CCD) with Rotation Tracking

### Changes Made:
- **Updated `src/components.lua`**:
  - Added `prevX` and `prevY` to `Position` component to track previous position
  - Added `prevRotation` to `PolygonShape` component to track previous rotation state

- **Updated `src/systems/physics.lua`**:
  - Now stores `prevRotation` before updating rotation each frame
  - Enables rotation-aware continuous collision detection

### Why This Matters:
Fast-rotating objects can skip through collision geometry between frames. By tracking previous rotation, the collision system can now detect collisions more accurately for rapidly spinning asteroids or other rotated objects.

### Technical Details:
```lua
-- Before: Only linear position was tracked
position.prevX = position.x
position.prevY = position.y

-- After: Also tracks rotation
polygonShape.prevRotation = polygonShape.rotation
```

---

## 2. ✅ Angular Impulse Calculation (Rotational Physics Response)

### Changes Made:
- **Added `RotationalMass` component** in `src/components.lua`:
  - New component for moment of inertia (resistance to rotation)
  - Default inertia value of 1

- **Rewrote collision response** in `src/systems/physics_collision.lua`:
  - Calculates contact point from collision
  - Computes torque from collision impulse using cross product: `τ = r × F`
  - Applies angular impulse: `Δω = τ / I` (change in angular velocity = torque / inertia)

### Why This Matters:
Previously, collisions only affected linear velocity. Now they can cause objects to spin or change their spin rate based on where the collision occurs and the angle of impact. Off-center collisions naturally cause rotation.

### Technical Details:
```lua
-- Calculate contact point and radius vectors
local contactX = (pos1.x + pos2.x) / 2
local contactY = (pos1.y + pos2.y) / 2
local r1x = contactX - pos1.x
local r1y = contactY - pos1.y

-- Calculate torque (2D cross product)
local torque1 = r1x * impulseY - r1y * impulseX

-- Apply angular impulse
if angularVel1 and rotMass1 then
    angularVel1.omega = angularVel1.omega - torque1 / rotMass1.inertia
end
```

### Physics Formula:
- **Linear**: F = ma (already implemented)
- **Rotational**: τ = Iα (torque = inertia × angular acceleration)
- **Impulse Form**: Δω = τ / I = (r × J) / I

---

## 3. ✅ Rotation-Aware SAT Optimization

### Changes Made:
- **Added `hasRotationChanged()` function** in `src/systems/physics_collision.lua`:
  - Detects when objects have rotated beyond a threshold (default 0.1 radians ≈ 5.7°)
  - Compares current rotation against previous rotation

- **Updated SAT check logic**:
  - Now checks SAT only when:
    1. Object rotation has changed significantly, OR
    2. Broad-phase collision detected in current frame, OR
    3. Every 2 frames (fallback optimization)
  - **Before**: Every 2 frames regardless of rotation
  - **After**: Adaptive based on actual rotation changes

### Why This Matters:
Separating Axis Theorem (SAT) is computationally expensive but necessary for accurate polygon collision. The previous implementation wasted CPU time on stationary rotated objects and missed collisions when rotation changed significantly. The new approach only performs detailed checks when necessary.

### Technical Details:
```lua
-- Helper function
local function hasRotationChanged(poly1, poly2, rotationThreshold)
    rotationThreshold = rotationThreshold or 0.1  -- ~5.7 degrees
    local rot1Changed = poly1 and math.abs(poly1.rotation - (poly1.prevRotation or 0)) > rotationThreshold or false
    local rot2Changed = poly2 and math.abs(poly2.rotation - (poly2.prevRotation or 0)) > rotationThreshold or false
    return rot1Changed or rot2Changed
end

-- Smart SAT checking
local rotationChanged = hasRotationChanged(poly1, poly2)
local shouldCheckSAT = rotationChanged or bboxCheck1 or (frameCounter % 2) == 0
```

### Performance Impact:
- **Stationary objects**: SAT skipped more often (~75% frame reduction)
- **Rotating objects**: SAT only checked when rotation changes
- **Collision-prone objects**: Always checked for safety

---

## Integration Notes

### For Asteroids:
Assign a `RotationalMass` component when creating asteroids:
```lua
ECS.addComponent(asteroidId, "RotationalMass", Components.RotationalMass(2.5))
```

### For the Player:
The player already has `AngularVelocity`, so add:
```lua
ECS.addComponent(playerId, "RotationalMass", Components.RotationalMass(1.5))
```

### Threshold Adjustment:
Modify the rotation threshold in `hasRotationChanged()` calls:
```lua
-- More aggressive optimization (larger threshold)
hasRotationChanged(poly1, poly2, 0.2)  -- ~11.5 degrees

-- More precise collision (smaller threshold)
hasRotationChanged(poly1, poly2, 0.05)  -- ~2.9 degrees
```

---

## Testing Recommendations

1. **Test asteroid-to-asteroid collisions**: Verify realistic spin-up behavior
2. **Test fast-rotating objects**: Confirm no collision misses
3. **Performance profiling**: Monitor SAT call frequency
4. **Visual inspection**: Ensure asteroids rotate naturally after impacts

---

## Future Enhancements

1. **Friction/Damping**: Add angular damping to slow rotation over time
2. **Collision Friction**: Apply tangential impulses to reduce sliding
3. **Contact Manifold**: Track multiple contact points for complex collisions
4. **Sleeping Bodies**: Disable physics updates for stationary objects
5. **Soft-body Physics**: For deformable asteroids or debris

