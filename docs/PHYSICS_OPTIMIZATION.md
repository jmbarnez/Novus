# Physics Optimization Guide

## Current Status
- **Broad-phase**: O(n²) naive collision checks
- **CCD**: Swept circle collision added (prevents tunneling)
- **Velocities**: Modest (asteroids 10-40 px/frame, items up to 200 px/frame)

## When to Use Quadtree

### Performance Characteristics
| Entity Count | Current | With Quadtree | Benefit |
|---|---|---|---|
| 10 | ~50 checks | ~20 checks | Not needed |
| 25 | ~300 checks | ~60 checks | Marginal |
| 50 | ~1200 checks | ~150 checks | Recommended |
| 100 | ~4950 checks | ~400 checks | Highly recommended |

### Use Quadtree When:
- More than 50 physics entities on screen
- Frame rate drops below 60 FPS during heavy combat
- You want to scale to many asteroids/items

### Don't Use Quadtree When:
- Less than 30 concurrent physics entities
- Performance is already 60+ FPS
- You're optimizing prematurely

## How to Enable Quadtree

### Option 1: Simple (Recommended)
Replace broad-phase in `physics_collision.lua`:

```lua
-- In PhysicsCollisionSystem.update():
-- Instead of:
for i = 1, #physicsEntities do
    for j = i + 1, #physicsEntities do
        -- check collision

-- Use:
local Quadtree = require('src.systems.quadtree')
local tree = Quadtree.create(0, 0, 1920, 1080)
for _, entityId in ipairs(physicsEntities) do
    local pos = ECS.getComponent(entityId, "Position")
    local coll = ECS.getComponent(entityId, "Collidable")
    Quadtree.insert(tree, entityId, pos, coll.radius)
end

for _, entityId in ipairs(physicsEntities) do
    local pos = ECS.getComponent(entityId, "Position")
    local coll = ECS.getComponent(entityId, "Collidable")
    local nearby = Quadtree.getNearby(tree, pos.x, pos.y, coll.radius * 3)
    for _, other in ipairs(nearby) do
        -- check collision with other
```

### Option 2: Persistent Tree (Advanced)
Maintain quadtree across frames and update entity positions incrementally (requires more code, better for 100+ entities).

## Other Optimizations

### 1. **Frame Skipping for SAT**
Only check polygon-polygon (expensive SAT) every 2-3 frames for asteroids:
```lua
if entity1.asteroidCheckFrame and entity1.asteroidCheckFrame < love.timer.getTime() then
    -- Check polygon-polygon collision
    entity1.asteroidCheckFrame = love.timer.getTime() + 0.033 * 2 -- Skip 2 frames
end
```

### 2. **Sleeping Bodies**
Mark entities as "asleep" when velocity near 0, skip their collision checks:
```lua
if math.sqrt(vel.vx^2 + vel.vy^2) < 0.1 then
    entity.sleeping = true
end
```

### 3. **Distance-Based LOD**
Reduce collision precision for distant asteroids:
```lua
local dist = math.sqrt(dx^2 + dy^2)
if dist > 500 then
    -- Skip detailed SAT, use bounding circles only
end
```

## Current Implementation Status
- ✅ Swept circle collision detection added (CCD)
- ✅ Quadtree utility created (optional)
- ✅ SAT for polygon-polygon working
- ⚠️ Quadtree NOT YET INTEGRATED (requires refactoring broad-phase loop)

## Recommendations
1. **Keep current setup** until you have 50+ entities on screen
2. **Monitor performance** with `love.window.showMessageBox()` displaying FPS
3. **Integrate quadtree** only if needed (follow "Option 1" above)
4. **Profile first**: Use `love.profiler` if adding quadtree complexity
