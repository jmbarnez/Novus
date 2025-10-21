# Rendering Performance Optimizations

## Problem
Game running at only 70 FPS instead of expected 144+ FPS with relatively modest entity count:
- 150 asteroids
- 18 ships (player + 15 enemies + 3 collectors)
- Various particles, projectiles, and effects

## Root Causes Identified

### 1. **Shield Impact System - Major Bottleneck** ⚠️
**Problem**: Each shield impact effect was drawing **64 line segments** with complex angular calculations and alpha blending.

**Impact**: 
- 64 iterations per shield impact
- Complex trigonometry per segment (sin, cos, atan2)
- Alpha blending calculations
- Multiple shield impacts could happen simultaneously in combat

**Fix Applied**: 
```lua
-- Reduced from 64 to 16 segments (75% reduction)
local numSegments = 16  -- Was 64
```

**Performance Gain**: ~4x faster shield rendering, estimated 5-10 FPS gain when shields are active.

---

### 2. **Asteroid Health Bar Rendering - Double Loop**
**Problem**: Render system was querying and iterating over all 150 asteroids **twice per frame**:
1. First loop: Check which asteroid is being hovered by mouse
2. Second loop: Draw health bars for hovered/damaged asteroids

**Impact**:
- 300 iterations per frame (150 × 2)
- Each iteration involved component queries and calculations
- Mouse coordinate transformations recalculated every frame

**Fix Applied**: 
```lua
-- Only run asteroid health bar logic every other frame
local frameSkip = love.timer.getTime() * 60
if math.floor(frameSkip) % 2 == 0 then
    -- Asteroid hover detection and health bar rendering
end
```

**Performance Gain**: 50% reduction in asteroid rendering overhead, estimated 10-15 FPS gain.

---

### 3. **Wreckage Health Bar Rendering**
**Problem**: Same issue as asteroids - querying and rendering health bars for all wreckage pieces every frame.

**Fix Applied**: Same frame-skipping optimization (every other frame).

**Performance Gain**: 5-10 FPS gain when wreckage is present.

---

### 4. **Entity Query Overhead**
**Problem**: The render system was making many `ECS.getEntitiesWith()` calls per frame:
- Trail particles
- Debris particles  
- Laser beams
- Renderable entities
- Asteroid entities (twice!)
- Wreckage entities
- Magnetic field ships
- Camera entities (multiple times)
- Controllers for targeting

**Current State**: Most queries are necessary, but asteroid/wreckage queries are now skipped every other frame.

**Future Optimization**: Cache entity lists that don't change frequently (asteroids, ships).

---

## Additional Bottlenecks Not Yet Addressed

### 5. **Parallax Starfield Rendering**
**Issue**: Drawing 940 individual stars per frame:
- Layer 1: 40 stars (static, twinkling)
- Layer 2: 400 stars (parallax 0.01)
- Layer 3: 300 stars (parallax 0.03)
- Layer 4: 200 stars (parallax 0.08)

Each star requires:
- Individual `setColor()` call
- Modulo calculations for parallax layers
- Twinkling calculations (sin/cos for static layer)

**Potential Fix**: Batch stars into a single mesh or use sprite batching.

**Estimated Gain**: 5-10 FPS

---

### 6. **Health Bar Rendering for ALL Ships**
**Issue**: Health/shield bars are drawn for every enemy ship, every frame, regardless of distance or visibility.

**Current Code**:
```lua
if ECS.hasComponent(entityId, "Hull") and not isPlayer then
    -- Draw health bar for EVERY enemy
end
```

**Potential Fix**: 
- Only render health bars for ships within camera view
- Use distance culling for far-away ships
- Skip rendering every other frame (like asteroids)

**Estimated Gain**: 3-5 FPS

---

### 7. **Polygon Vertex Transformations**
**Issue**: Each asteroid (polygon) recalculates all vertex transformations every frame:
```lua
for i = 1, #vertices do
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    local rotatedX = v.x * cos - v.y * sin
    local rotatedY = v.x * sin + v.y * cos
end
```

**Potential Fix**: 
- Cache transformed vertices
- Only recalculate when rotation changes
- Use Love2D's mesh system

**Estimated Gain**: 10-15 FPS

---

### 8. **Trail Particle Overhead**
**Issue**: Trail system creates many short-lived entities with full ECS overhead.

**Current Mitigation**: Already has `maxParticles` limit.

**Potential Fix**: Use particle system batch instead of individual entities.

**Estimated Gain**: 5 FPS

---

## Performance Gains Summary

| Optimization | Status | Est. FPS Gain |
|--------------|--------|---------------|
| Shield impact segments (64→16) | ✅ Applied | 5-10 FPS |
| Asteroid health bars (frame skip) | ✅ Applied | 10-15 FPS |
| Wreckage health bars (frame skip) | ✅ Applied | 5-10 FPS |
| Parallax batching | ❌ Not Applied | 5-10 FPS |
| Ship health bar culling | ❌ Not Applied | 3-5 FPS |
| Polygon vertex caching | ❌ Not Applied | 10-15 FPS |
| Trail particle batching | ❌ Not Applied | 5 FPS |

**Total Applied**: ~20-35 FPS gain expected
**Total Available**: ~43-70 FPS gain possible

---

## Expected Results After Applied Optimizations

**Before**: 70 FPS
**After**: 90-105 FPS (with current optimizations)
**Potential**: 113-140 FPS (with all optimizations)

---

## Testing

Run the game and monitor FPS:
1. Idle (no combat): Should see immediate improvement
2. During combat with shields: Should see major improvement (shield impacts optimized)
3. While hovering over asteroids: Frame skipping should maintain smooth FPS

---

## Further Optimization Opportunities

### VSync
**Note**: Game currently has VSync disabled (`love.window.setVSync(0)`).

If targeting 60 FPS, enabling VSync would:
- Reduce unnecessary rendering work
- Eliminate screen tearing
- Save battery on laptops

### Batching System
Implement a batching renderer for static geometry:
- Batch all asteroid polygons into single draw call
- Use instancing for identical shapes
- Update batch only when entities are created/destroyed

### Spatial Culling
Already using Quadtree for collision detection. Extend it for rendering:
- Only render entities within camera frustum + margin
- Skip rendering distant small entities
- Implement LOD system for far objects

### GPU Optimization
- Use shaders for particle effects
- Move twinkling calculations to GPU
- Use hardware instancing for repeated shapes

---

## Monitoring

Add performance metrics to track:
- Entity count by type
- Render calls per frame
- Time spent in each render phase
- Entity query time vs render time

Example monitoring code:
```lua
local renderStart = love.timer.getTime()
-- render code
local renderTime = love.timer.getTime() - renderStart
print(string.format("Render: %.2fms", renderTime * 1000))
```

