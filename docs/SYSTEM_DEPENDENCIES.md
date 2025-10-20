# System Dependencies & Execution Order

**Document Version**: 1.0  
**Last Updated**: October 2025  
**Scope**: Defines all system interdependencies and execution order for the Space Drone Adventure ECS

---

## Table of Contents

1. [Execution Order](#execution-order)
2. [System Dependency Graph](#system-dependency-graph)
3. [System Details](#system-details)
4. [Component Requirements](#component-requirements)
5. [Data Flow Diagrams](#data-flow-diagrams)
6. [Critical Dependencies](#critical-dependencies)
7. [Adding New Systems](#adding-new-systems)

---

## Execution Order

Systems are registered and executed in this specific order in `src/core.lua`. **This order is critical** - changing it will break gameplay logic.

### Physics & Movement (First)
1. **PhysicsSystem** - Applies physics (velocity, acceleration, position integration)
2. **PhysicsCollisionSystem** - Handles physics-based collisions
3. **BoundarySystem** - Constrains entities within world bounds

### Input & Camera (Next)
4. **InputSystem** - Processes player keyboard/mouse input → acceleration
5. **RenderSystem** - Prepares world state for rendering
6. **CameraSystem** - Updates camera position to follow player

### UI & Visuals (Before Logic)
7. **UISystem** - Handles UI state and rendering
8. **HUDSystem** - Renders heads-up display (speed, health, etc.)
9. **TrailSystem** - Updates and renders particle trails

### Combat & AI Decision-Making (Early Logic)
10. **CombatAlertSystem** - Detects combat situations
11. **AIArbiterSystem** - Coordinates multi-system AI behavior
12. **AISystem** - Executes patrol/chase/orbit AI logic
13. **CollisionSystem** - Detects entity-entity collisions (quadtree-based)

### Item Collection & Loot (Mid Logic)
14. **MagnetSystem** - Attracts and collects items into cargo
15. **EnemyMiningSystem** - Controls enemy mining behavior

### Destruction & Cleanup (Late Logic)
16. **DestructionSystem** - Handles entity destruction, spawns loot
17. **DebrisSystem** - Manages debris particles
18. **TurretSystem** - Fires turrets, manages cooldowns
19. **ProjectileSystem** - Updates projectile positions and lifetime
20. **ShieldImpactSystem** - Renders shield hit effects

---

## System Dependency Graph

```
INPUT LAYER
│
├─→ InputSystem
│   └─→ Acceleration component
│
PHYSICS LAYER
│
├─→ PhysicsSystem (reads Acceleration)
│   └─→ Velocity, Position components
│
├─→ PhysicsCollisionSystem (reads Position)
│   └─→ Physics collision responses
│
├─→ BoundarySystem (reads Position)
│   └─→ Enforces world bounds
│
VISUAL LAYER
│
├─→ CameraSystem (reads Position of camera target)
│   └─→ Camera position follows player
│
├─→ RenderSystem (reads all Position, Renderable, etc.)
│   └─→ Visual output
│
├─→ HUDSystem (reads Health, Velocity, UI state)
│   └─→ HUD rendering
│
├─→ TrailSystem (reads Velocity, TrailEmitter)
│   └─→ Trail particle rendering
│
DECISION LAYER
│
├─→ CombatAlertSystem (reads Position, AI state)
│   └─→ Triggers alert flags
│
├─→ AIArbiterSystem (reads combat alerts, AI priority)
│   └─→ Coordinates AI systems
│
├─→ AISystem (reads AI state, Position, targets)
│   ├─→ Sets acceleration for patrol/chase/orbit
│   └─→ Outputs: Acceleration, AI state updates
│
├─→ CollisionSystem (reads Position, PolygonShape)
│   └─→ Detects entity collisions, triggers damage
│
ACTION LAYER
│
├─→ MagnetSystem (reads MagneticField, Item Position, Cargo)
│   ├─→ Attracts items
│   ├─→ Collects items into cargo
│   └─→ Destroys collected item entities
│
├─→ EnemyMiningSystem (reads MiningTarget, Position)
│   ├─→ Sets acceleration toward asteroids
│   └─→ Mines asteroids
│
COMBAT & DESTRUCTION LAYER
│
├─→ DestructionSystem (reads Hull, reads destroyed entities)
│   ├─→ Destroys entities when hull ≤ 0
│   ├─→ Spawns wreckage (Wreckage component)
│   ├─→ Spawns items (Item component)
│   ├─→ Triggers notifications
│   └─→ Removes entities from ECS
│
├─→ DebrisSystem (reads Debris particles, lifetime)
│   └─→ Cleans up expired debris
│
├─→ TurretSystem (reads Turret, target info)
│   ├─→ Manages cooldowns
│   ├─→ Fires turrets → creates Projectile entities
│   └─→ Outputs: Projectile entities
│
├─→ ProjectileSystem (reads Projectile, Position, lifetime)
│   ├─→ Updates projectile positions
│   ├─→ Checks lifetime
│   ├─→ Collides with ships (see CollisionSystem)
│   └─→ Removes expired projectiles
│
└─→ ShieldImpactSystem (reads Shield, impact position)
    └─→ Renders shield hit visual effects
```

---

## System Details

### **1. PhysicsSystem** ⚙️
- **File**: `src/systems/physics.lua`
- **Reads**: Acceleration, Velocity, Physics component
- **Writes**: Velocity, Position
- **Dependencies**: None (must run first)
- **Why First**: All other systems depend on Position being current

### **2. PhysicsCollisionSystem** 🔵
- **File**: `src/systems/physics_collision.lua`
- **Reads**: Position, PolygonShape, Physics component
- **Writes**: Velocity (collision response)
- **Depends On**: PhysicsSystem (needs current Position)
- **Blocks**: Must run before AI/movement systems that read Position

### **3. BoundarySystem** 🌍
- **File**: `src/systems/boundary.lua`
- **Reads**: Position, Boundary component
- **Writes**: Position (constrains to bounds)
- **Depends On**: PhysicsSystem (needs current Position)
- **Why Early**: Prevents entities from leaving world

### **4. InputSystem** ⌨️
- **File**: `src/systems/input.lua`
- **Reads**: InputControlled component, player input events
- **Writes**: Acceleration
- **Depends On**: PhysicsSystem (Position already valid for camera transforms)
- **Why After Physics**: Uses current Position for camera-relative input

### **5. RenderSystem** 🎨
- **File**: `src/systems/render.lua`
- **Reads**: Position, Renderable, PolygonShape (all visual components)
- **Writes**: Canvas (rendering target)
- **Depends On**: PhysicsSystem, CameraSystem (needs current camera position)
- **Note**: Can run early; prepares visual state

### **6. CameraSystem** 📷
- **File**: `src/systems/camera.lua`
- **Reads**: Position of CameraTarget entity
- **Writes**: Camera component (position)
- **Depends On**: PhysicsSystem (needs current player Position)
- **Blocks**: InputSystem (needs current camera for input transform)

### **7. UISystem** 🖼️
- **File**: `src/systems/ui.lua`
- **Reads**: UI component, input events
- **Writes**: UI state (window positions, etc.)
- **Depends On**: None (independent)
- **Note**: Can run at any time; typically early

### **8. HUDSystem** 📊
- **File**: `src/systems/hud.lua`
- **Reads**: Health, Velocity, Hull, Shield, Turret components
- **Writes**: Canvas (HUD rendering)
- **Depends On**: RenderSystem (uses same canvas)
- **Note**: Pure rendering, no state changes

### **9. TrailSystem** ✨
- **File**: `src/systems/trail.lua`
- **Reads**: TrailEmitter, Velocity, TrailParticle entities
- **Writes**: New TrailParticle entities (particles)
- **Depends On**: PhysicsSystem (reads Velocity)
- **Note**: Pure rendering/particle management, no game logic impact

### **10. CombatAlertSystem** ⚠️
- **File**: `src/systems/combat_alert.lua`
- **Reads**: Position, AI component, target tracking
- **Writes**: AI state (alert flag)
- **Depends On**: PhysicsSystem (reads Position)
- **Blocks**: AIArbiterSystem (sets alert state that affects decisions)

### **11. AIArbiterSystem** 🧠
- **File**: `src/systems/ai_arbiter.lua`
- **Reads**: CombatAlert state, AI priority/state
- **Writes**: AI state (decision flags)
- **Depends On**: CombatAlertSystem (needs alert flags)
- **Blocks**: AISystem (sets which AI behavior to use)

### **12. AISystem** 🤖
- **File**: `src/systems/ai.lua`
- **Reads**: AI state, Position, targets, Velocity
- **Writes**: Acceleration
- **Depends On**: AIArbiterSystem (needs decision flags)
- **Blocks**: None (outputs Acceleration for PhysicsSystem next frame)

### **13. CollisionSystem** 💥
- **File**: `src/systems/collision.lua`
- **Reads**: Position, PolygonShape (entities and projectiles)
- **Writes**: Hull (damage)
- **Depends On**: PhysicsSystem (needs current Position)
- **Uses**: Quadtree for spatial partitioning
- **Critical**: Must run after movement but before destruction checks

### **14. MagnetSystem** 🧲
- **File**: `src/systems/magnet.lua`
- **Reads**: MagneticField, Position, Item component, Cargo
- **Writes**: Position (item movement), destroys items, Cargo (inventory)
- **Depends On**: PhysicsSystem (needs current Position)
- **Blocks**: DestructionSystem (destroys Item entities)

### **15. EnemyMiningSystem** ⛏️
- **File**: `src/systems/enemy_mining.lua`
- **Reads**: AI type, Position, MiningTarget, asteroid positions
- **Writes**: Acceleration
- **Depends On**: AISystem (uses same Acceleration output)
- **Blocks**: DestructionSystem (reduces asteroid hull)

### **16. DestructionSystem** 💀
- **File**: `src/systems/destruction.lua`
- **Reads**: Hull component (checks if ≤ 0)
- **Writes**: Spawns Item/Wreckage entities, destroys parent
- **Depends On**: CollisionSystem (produces damage), MagnetSystem (removes collected items)
- **Blocks**: None directly (cleanup happens via ECS)

### **17. DebrisSystem** 🌪️
- **File**: `src/systems/debris.lua`
- **Reads**: Debris particle lifetime
- **Writes**: Destroys expired particles
- **Depends On**: None (pure cleanup)
- **Note**: Runs after destruction for cleanup

### **18. TurretSystem** 🔫
- **File**: `src/systems/turret.lua`
- **Reads**: Turret, target, cooldown timers
- **Writes**: Creates Projectile entities, updates cooldown
- **Depends On**: None (independent)
- **Blocks**: ProjectileSystem (creates the projectiles it manages)

### **19. ProjectileSystem** 🎯
- **File**: `src/systems/projectile.lua`
- **Reads**: Projectile lifetime, Position
- **Writes**: Updates Position, removes expired projectiles
- **Depends On**: TurretSystem (creates projectiles)
- **Blocks**: None (pure movement)

### **20. ShieldImpactSystem** ⚡
- **File**: `src/systems/shield_impact.lua`
- **Reads**: Shield, impact position/visual state
- **Writes**: Shield impact particles
- **Depends On**: CollisionSystem (knows where impacts happen)
- **Note**: Pure visual effect system, no gameplay impact

---

## Component Requirements

Each system requires specific components to operate:

| System | Required Components | Optional Components |
|--------|---------------------|---------------------|
| PhysicsSystem | Velocity, Physics, Position | Acceleration |
| PhysicsCollisionSystem | Position, PolygonShape | Physics |
| BoundarySystem | Position, Boundary | - |
| InputSystem | InputControlled, Position | - |
| CameraSystem | Camera, Position | - |
| AISystem | AI, Position, Velocity | - |
| CollisionSystem | Position, PolygonShape | Hull |
| MagnetSystem | MagneticField, Cargo, Position | - |
| TurretSystem | Turret, Position | - |
| ProjectileSystem | Projectile, Position, Velocity | - |
| DestructionSystem | Hull | - |
| TrailSystem | TrailEmitter, Velocity | - |

---

## Data Flow Diagrams

### **Input to Movement Pipeline**
```
InputSystem
    ↓ (outputs Acceleration)
PhysicsSystem
    ↓ (outputs Velocity, Position)
BoundarySystem (constrains Position)
    ↓
CameraSystem (follows player Position)
    ↓
RenderSystem (renders at Position)
```

### **AI Decision Pipeline**
```
CollisionSystem (detects nearby enemies)
    ↓ (sets hostile state)
CombatAlertSystem (flags alert)
    ↓
AIArbiterSystem (decides patrol vs. combat)
    ↓
AISystem (executes desired behavior)
    ↓ (outputs Acceleration)
PhysicsSystem (next frame)
```

### **Damage & Destruction Pipeline**
```
ProjectileSystem (positions projectiles)
    ↓
CollisionSystem (detects hits)
    ↓ (reduces Hull)
DestructionSystem (checks Hull ≤ 0)
    ↓ (destroys entity, spawns loot)
MagnetSystem (attracts loot)
    ↓ (collects into cargo)
```

### **Item Collection Pipeline**
```
DestructionSystem (spawns Item entities)
    ↓
MagnetSystem (attracts items)
    ↓ (pulls toward player)
MagnetSystem (proximity check)
    ↓ (collects into Cargo)
ECS (destroys Item entity)
```

---

## Critical Dependencies

### **MUST NOT CHANGE** ✋
These dependencies are hard-coded and changing them will break the game:

1. **PhysicsSystem before everything else**
   - All systems depend on Position being accurate
   - If moved: Physics won't integrate properly, camera will lag, AI will target wrong positions

2. **CollisionSystem after PhysicsSystem but before DestructionSystem**
   - Collision must resolve before checking for destruction
   - If moved: Ships won't take damage, or damage applies but entity isn't destroyed

3. **MagnetSystem before DestructionSystem**
   - Magnet must destroy items before the main destruction check
   - If moved: Players will lose collected items, or items won't disappear after collection

4. **AISystem after AIArbiterSystem**
   - AI needs decision state from Arbiter
   - If moved: AI won't respond to combat situations correctly

5. **CameraSystem after PhysicsSystem, before RenderSystem**
   - Camera must follow player after movement, before rendering
   - If moved: Camera will lag or render won't work

### **Can Be Flexible** 🔧
These can be reordered without breaking core gameplay:

- TrailSystem (pure visual)
- HUDSystem (pure visual)
- ShieldImpactSystem (pure visual)
- DebrisSystem (cleanup only)

---

## Adding New Systems

### **Step 1: Identify Dependencies**
Ask: "What data must already exist when this system runs?"

**Example**: New "Minimap System"
- Depends On: Position, Camera (needs player location)
- Must Run After: CameraSystem (needs current camera)

### **Step 2: Identify Dependents**
Ask: "What data does this system produce that other systems need?"

**Example**: Minimap System
- Produces: UI rendering (independent)
- Is Blocking: Nothing (pure visual)

### **Step 3: Find Insertion Point**
Place in order based on when data becomes available.

```
NEW SYSTEM PLACEMENT FOR MINIMAP:
...
CameraSystem (provides camera position) ← Minimap depends on this
MinimapSystem (NEW) ← Add here
HUDSystem (provides UI rendering)
...
```

### **Step 4: Add to core.lua**
```lua
-- In src/core.lua registration section
ECS.registerSystem("MinimapSystem", Systems.MinimapSystem)
-- Place at correct position in order
```

### **Step 5: Document**
- Add entry to System Details section above
- Update Data Flow Diagram if complex
- Document component requirements

---

## Debugging System Issues

### **Symptom: Data appears outdated**
**Cause**: System running before its dependency
**Fix**: Check execution order in core.lua

### **Symptom: System crashes with nil component**
**Cause**: Querying for components on wrong entity type
**Fix**: Check Component Requirements table above

### **Symptom: Changes don't take effect**
**Cause**: System running after another system overwrites data
**Fix**: Trace data flow diagram to find conflict

### **Symptom: Circular dependencies**
**Cause**: System A depends on B, B depends on A
**Fix**: Refactor to separate concerns into more systems, or use deferred updates

---

## Summary Table

| Order | System | Type | Depends On | Blocks |
|-------|--------|------|-----------|---------|
| 1 | PhysicsSystem | Physics | Nothing | Everything |
| 2 | PhysicsCollisionSystem | Physics | Physics | AI, Collision |
| 3 | BoundarySystem | Physics | Physics | Rendering |
| 4 | InputSystem | Input | Physics, Camera | Movement |
| 5 | RenderSystem | Rendering | Physics, Camera | HUD, Trail |
| 6 | CameraSystem | Camera | Physics | Rendering, Input |
| 7 | UISystem | UI | Nothing | - |
| 8 | HUDSystem | Rendering | Physics, Health | - |
| 9 | TrailSystem | Rendering | Physics, Velocity | - |
| 10 | CombatAlertSystem | Logic | Physics, Position | AI Arbiter |
| 11 | AIArbiterSystem | Logic | CombatAlert | AI System |
| 12 | AISystem | Logic | AIArbiter | - |
| 13 | CollisionSystem | Physics | Physics, Position | Destruction |
| 14 | MagnetSystem | Logic | Physics, Items | Destruction |
| 15 | EnemyMiningSystem | Logic | AI, Physics | - |
| 16 | DestructionSystem | Cleanup | Collision, Magnet | - |
| 17 | DebrisSystem | Cleanup | Nothing | - |
| 18 | TurretSystem | Combat | Physics | Projectiles |
| 19 | ProjectileSystem | Movement | TurretSystem | Collision |
| 20 | ShieldImpactSystem | Rendering | Collision | - |

---

**End of Document**
