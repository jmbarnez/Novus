# Physics System Improvements

## Overview
This document describes the three high-priority physics improvements implemented to make the game feel more realistic and smooth.

## 1. Proper Mass Distribution ⚖️

### What Changed
All entities now have **realistic mass values** that reflect their size and type. Mass directly affects how entities respond to collisions and forces.

### Mass Scale Reference
| Entity Type | Mass (kg) | Notes |
|------------|-----------|-------|
| **Projectiles** | 0.5 - 1.5 | Very light; easily deflected by heavier objects |
| **Item Drops** | 0.8 | Light cargo items |
| **Wreckage** | 2.0 | Debris from destroyed ships |
| **Starter Drone** | 5 | Lightest playable ship |
| **Red Scout** | 8 | Light enemy scout |
| **Standard Combat** | 15 | Medium combat ship |
| **Starter Hexagon** | 12 | Medium starter ship |
| **Small Asteroids** | 50 - 200 | Size²×0.5 scaling |
| **Large Asteroids** | 200 - 500 | Much heavier; hard to move |

### Impact on Gameplay
- **Asteroids feel massive**: Projectiles bounce off asteroids instead of pushing them
- **Ship collisions matter**: Heavier ships push lighter ships around
- **Realistic momentum**: Heavy objects transfer more momentum in collisions
- **Strategic choices**: Ship mass affects maneuverability vs. collision resistance

### Implementation
```lua
-- Ship designs now specify mass:
mass = 15  -- Standard combat ship

-- Asteroids calculate mass from size:
local asteroidMass = size * size * 0.5  -- Scales with area

-- Projectiles are very light:
Components.Physics(1.0, 0.5, 0.99)  -- friction, mass, angularDamping
```

---

## 2. Angular Damping (Rotational Friction) 🌀

### What Changed
Added **angular damping** to the physics system, which gradually slows down spinning objects over time. Different entity types have different damping values.

### Angular Damping Scale
| Entity Type | Damping | Behavior |
|------------|---------|----------|
| **Ships** | 0.95 | High damping - controlled rotation stops quickly |
| **Item Drops** | 0.90 | High damping - items stabilize fast |
| **Wreckage** | 0.90 | High damping - debris settles |
| **Asteroids** | 0.985 | Low damping - slow natural spin decay |
| **Projectiles** | 0.99 | Minimal damping - maintain trajectory |

### Impact on Gameplay
- **Ships feel responsive**: Rotation stops when you stop turning (no endless spinning)
- **Items settle**: Dropped cargo doesn't tumble forever
- **Asteroids drift realistically**: Maintain slow rotation for visual interest
- **Better control**: Players have precise control over ship orientation

### Implementation
```lua
-- Added to Physics component:
Components.Physics = function(friction, mass, angularDamping)
    return {
        friction = friction or 0.98,
        mass = mass or 1,
        angularDamping = angularDamping or 0.98  -- New parameter
    }
end

-- Applied every frame in PhysicsSystem:
if physics and physics.angularDamping then
    angularVelocity.omega = angularVelocity.omega * physics.angularDamping
end
```

---

## 3. Tuned Restitution (Bounce) 🏀

### What Changed
Changed collision restitution from **0.0 (perfectly inelastic)** to **0.3 (some bounce)**. This makes collisions feel more dynamic and realistic for space physics.

### Before vs After
| Scenario | Before (0.0) | After (0.3) |
|----------|--------------|-------------|
| **Ship hits asteroid** | Sticks and slides | Bounces slightly, feels natural |
| **Projectile impact** | Dead stop | Small rebound effect |
| **Ship collision** | Objects merge momentum | Objects separate naturally |
| **Energy loss** | 100% (unrealistic) | 70% (realistic for space) |

### Impact on Gameplay
- **Dynamic collisions**: Objects bounce apart instead of sticking together
- **More interesting physics**: Glancing blows deflect naturally
- **Space-like feel**: Objects don't behave like they're in molasses
- **Better separation**: Prevents objects from getting stuck together

### Implementation
```lua
-- Changed in physics_collision.lua resolveCollision():
local restitution = 0.3  -- Some bounce for realistic space physics (was 0.0)
local j = -(1 + restitution) * velAlongNormal
```

---

## Technical Details

### Physics Component Signature
```lua
Components.Physics(friction, mass, angularDamping)
-- friction: 0-1, closer to 1 = less friction (space = 0.999)
-- mass: kg equivalent, affects collision response
-- angularDamping: 0-1, closer to 1 = less damping
```

### Mass in Collision Response
The impulse calculation now properly uses mass:
```lua
local j = -(1 + restitution) * velAlongNormal
j = j / (1 / phys1.mass + 1 / phys2.mass)

-- Heavier objects (higher mass) receive less velocity change
vel1.vx = vel1.vx - (1 / phys1.mass) * impulseX
```

### Angular Damping Application
Applied every frame before rotation update:
```lua
-- In PhysicsSystem.update():
angularVelocity.omega = angularVelocity.omega * physics.angularDamping
polygonShape.rotation = polygonShape.rotation + angularVelocity.omega * dt
```

---

## Testing & Validation

### Expected Behaviors
1. **Asteroid Impact Test**: Fire projectiles at asteroids
   - ✅ Projectiles should bounce off or shatter
   - ✅ Asteroids should barely move
   
2. **Ship Collision Test**: Ram ships into each other
   - ✅ Heavier ship pushes lighter ship
   - ✅ Both ships bounce apart slightly
   
3. **Rotation Test**: Spin a ship and let go
   - ✅ Ship rotation should slow down and stop
   - ✅ Asteroids should maintain slow spin
   
4. **Item Drop Test**: Destroy asteroid/ship
   - ✅ Items should tumble and then stabilize
   - ✅ Light items should be easily pushed around

---

## Medium Priority Improvements (IMPLEMENTED) ✅

See **[FORCE_SYSTEM.md](FORCE_SYSTEM.md)** for full documentation.

### Completed Features
- ✅ **Force Accumulator System**: Forces accumulate during frame, converted to acceleration at end
- ✅ **Calculated Moment of Inertia**: Shape-based rotational physics (long ships spin slower)
- ✅ **ForceUtils Module**: Helper functions for applying forces, torque, impulses
- ✅ **Automatic Integration**: Ships and asteroids automatically get proper inertia

### What This Enables
- Gravity fields (planets, black holes)
- Tractor beams for salvaging
- Magnetic item collection
- Wind/current effects
- Explosion push effects
- Off-center forces create realistic spin

## Future Improvements (Not Yet Implemented)

### Low Priority
- **Variable Restitution**: Different materials (metal, rock, shields) bounce differently
- **Better Center of Mass**: Off-center collisions create realistic torque

### Low Priority
- **Velocity-Dependent Effects**: High-speed collisions feel different
- **Collision Sounds**: Audio feedback based on mass and velocity
- **Particle Effects**: Visual feedback scaled to collision energy

---

## Configuration Reference

### Ship Mass Guidelines
- **Lightweight ships** (5-8 kg): Fast, agile, easily knocked around
- **Medium ships** (10-15 kg): Balanced, good for combat
- **Heavy ships** (20+ kg): Slow but stable, tank-like

### Damping Guidelines
- **High damping** (0.90-0.95): Controlled objects (ships, items)
- **Medium damping** (0.96-0.98): Debris, wreckage
- **Low damping** (0.985-0.999): Natural objects (asteroids)

### Restitution Guidelines
- **0.0**: Perfectly inelastic (clay, mud)
- **0.3**: Space collisions (current setting)
- **0.5**: Semi-elastic (wood, plastic)
- **0.8+**: Highly elastic (rubber balls)

---

## Performance Impact
✅ **Minimal** - All improvements are simple multiplications applied per-entity per-frame.

**Estimated cost**: ~0.1ms per 100 entities (negligible)

---

## Changelog

### Version 1.0 (October 21, 2025)
- ✅ Added `angularDamping` parameter to Physics component
- ✅ Implemented angular damping in PhysicsSystem
- ✅ Updated all ship designs with realistic mass values
- ✅ Updated all projectiles with light mass values
- ✅ Updated asteroid generation with heavy mass values
- ✅ Changed restitution from 0.0 to 0.3
- ✅ Updated item drops and wreckage with appropriate masses
- ✅ Added rotational inertia to static asteroids in core.lua

---

## Credits
**Design Philosophy**: Realistic space physics with arcade-style control
**Inspiration**: Elite Dangerous, Asteroids, Kerbal Space Program
