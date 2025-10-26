# Spawning System Overview

## Summary
Spawning in Space Drone Adventure is handled across multiple files and systems. Here's where all the spawning is handled:

---

## 1. **Core Game Initialization** (`src/core.lua`)
**Primary spawning entry point during game setup**

### Player & Game Entities:
- **Player Drone**: Created via `ShipLoader.createShip("starter_drone", 0, 0, "player", pilotId)`
- **Player Pilot Entity**: Created as a separate entity with InputControlled component
- **Camera**: Spawned and linked to player drone
- **UI Entity**: Created for all UI rendering
- **Starfield**: Created with parallax layers for background

### Initial Asteroid Spawning:
```lua
-- Asteroid cluster around spawn point (center)
Procedural.spawnMultiple("asteroid", Constants.asteroid_cluster_count, "cluster", {
    centerX = 0,
    centerY = 0,
    radius = Constants.asteroid_cluster_radius
})

-- Asteroid field line extending across map
-- 80 asteroids placed in a line from world_min_x to world_max_x
-- Each asteroid created individually with custom components
```

### Initial Enemy Ship Spawning:
- **5 Mining Laser Drones**: Spawned with `"mining_laser"` turret module, marked with `MiningAI` component
- **10 Cannon Drones**: Spawned with `"basic_cannon"` turret module, marked with `CombatAI` component
- **Total**: 15 AI-controlled enemy ships distributed across the map using `enemySpacing` calculation
- Uses `ShipLoader.createShip("red_scout", x, y, "ai")` for each enemy

---

## 2. **Procedural Generation System** (`src/procedural.lua`)
**Handles template-based entity generation**

### Key Functions:

#### `Procedural.spawnMultiple(templateName, count, spawnStrategy, strategyData)`
- Generates multiple entities using templates
- Implements collision avoidance with 150-unit minimum distance between entities
- Supports spawn strategies:
  - **"cluster"**: Random positions within radius from center
  - **"grid"**: Grid pattern layout
  - **"edge"**: Spawn at screen edges

#### `Procedural.generateEntity(templateName, spawnData)`
- Uses template to generate component data
- Currently supports: `"asteroid"` template

#### `Procedural.calculateSpawnPosition(strategy, data, index)`
- Calculates spawn position based on strategy type
- Returns spawn data with x, y, and angle

### Asteroid Template:
```lua
Procedural.registerTemplate("asteroid", function(spawnData)
    -- Generates all components for an asteroid:
    -- Position, Velocity, Physics, PolygonShape
    -- AngularVelocity, RotationalMass, Collidable
    -- Durability, Asteroid marker, Renderable
end)
```

---

## 3. **Ship Loading System** (`src/ship_loader.lua`)
**Factory for creating ship entities from design blueprints**

### Function: `ShipLoader.createShip(designId, x, y, controllerType, controllerId)`

**Parameters:**
- `designId`: Ship design to load (e.g., "starter_drone", "red_scout")
- `x, y`: Spawn position
- `controllerType`: "player" or "ai"
- `controllerId`: Only used for player ships (pilot entity ID)

**What Gets Created:**
1. Position, Velocity, Acceleration components
2. Physics component (friction, mass)
3. PolygonShape and Renderable (based on design)
4. Collidable component (collision radius)
5. Hull and Shield components (if defined in design)
6. Turret component (if turret slots > 0)
7. TrailEmitter component (for visual effects)
8. Magnet component (for item pickup)
9. Controller-specific components:
   - **Player**: ControlledBy, CameraTarget, Boundary, InputControlled link
   - **AI**: AIController with patrol/combat behavior

---

## 4. **Item Drop Spawning** (`src/systems/destruction.lua`)
**Spawned when asteroids or ships are destroyed**

### Function: `DestructionSystem.spawnItemDrops(x, y, entityType)`

**Triggered By:** `DestructionSystem.update()` when entities reach 0 durability

**Item Types Spawned:**
- **Asteroids destroyed**: 2-4 items (stone, iron mix)
- **Ships destroyed**: 1-2 scrap items

**How It Works:**
1. Random angle and distance from destruction point
2. Items get random velocity away from center
3. Each item type gets its own entity with Stack component
4. Items are magnetizable by player ships

### Function: `DestructionSystem.spawnScrapDrop(x, y)`
- Spawns 1-2 scrap pieces from destroyed wreckage
- Uses similar scatter pattern as item drops

---

## 5. **Wreckage Spawning** (`src/systems/wreckage.lua`)
**Spawned when ships are destroyed**

### Function: `WreckageSystem.spawnWreckage(x, y, sourceShip)`

**Creates:**
- Multiple wreckage pieces around destruction point
- Each piece is a destructible entity
- Wreckage can drop additional scrap when destroyed

---

## 6. **Debris/Particle Spawning** (`src/systems/debris.lua`)
**Visual effect particles spawned on impact/destruction**

### Function: `DebrisSystem.createDebris(x, y, count, color)`

**Triggered By:**
- Mining laser impacts: `src/turret_modules/mining_laser.lua`
- Salvage laser impacts: `src/turret_modules/salvage_laser.lua`
- Combat laser impacts: `src/turret_modules/combat_laser.lua`
- Enemy mining impacts: `src/systems/enemy_mining.lua`
- Entity destruction: `src/systems/destruction.lua`

**What Gets Created:**
- Visual debris particles (non-physical)
- Temporary visual effects only

---

## 7. **Projectile Spawning** (`src/turret_modules/*.lua`)
**Spawned when weapons fire**

### Spawned By Each Weapon:

#### Basic Cannon (`basic_cannon.lua`):
- Creates projectile 25 units away from ship in fire direction
- Entity: Projectile component with velocity
- `spawnX = startX + dirX * 25`
- `spawnY = startY + dirY * 25`

#### Combat Laser (`combat_laser.lua`):
- Creates laser line entity (not traditional projectile)
- Extends from turret to impact point

#### Mining Laser (`mining_laser.lua`):
- Creates laser line entity
- Similar to combat laser

#### Salvage Laser (`salvage_laser.lua`):
- Creates laser line entity

---

## 8. **Player Respawning** (`src/systems/destruction.lua`)
**Special spawning for player drone destruction**

### Function: `DestructionSystem.respawnPlayer(droneId, pilotId)`

**Triggered By:** When player's drone hull reaches 0 in `DestructionSystem.update()`

**What Happens:**
1. Drone position reset to (0, 0)
2. Velocity reset to (0, 0)
3. Hull restored to max
4. Shield restored to max (if present)
5. No destruction visual effects (just resets)

---

## 9. **Trail Particle Spawning** (`src/systems/trail.lua`)
**Visual trail particles behind moving ships**

### Function: `TrailSystem.update(dt)`

**Spawns Particles For:**
- Any entity with TrailEmitter component
- Continuously spawns during movement based on:
  - `trail_emit_rate`: Particles per second
  - `trail_max_particles`: Maximum concurrent trail particles
  - `trail_particle_life`: How long each particle lasts

---

## 10. **Enemy Mining Laser Spawning** (`src/systems/enemy_mining.lua`)
**Spawned when AI ships fire mining lasers**

### Function: `EnemyMiningSystem.spawnMinerLaser(...)`

**Creates:**
- Laser entity for visual representation
- Similar to player mining laser

---

## Spawn Location Map

| Entity | Location | Triggered By | Count |
|--------|----------|--------------|-------|
| Player Drone | (0, 0) | Game init | 1 |
| Asteroid Cluster | Center region | Game init | asteroid_cluster_count |
| Asteroid Line | Horizontal line across map | Game init | 80 |
| Enemy Mining Drones | Distributed evenly | Game init | 5 |
| Enemy Cannon Drones | Distributed evenly | Game init | 10 |
| Items (Asteroids) | Random scatter ±150 units | Asteroid destruction | 2-4 per asteroid |
| Items (Ships) | Random scatter ±150 units | Ship destruction | 1-2 per ship |
| Scrap (Wreckage) | Random scatter ±60 units | Wreckage destruction | 1-2 per wreckage |
| Wreckage | Destruction point | Ship destruction | varies |
| Debris Particles | Impact point | Weapon impact | varies |
| Projectiles | 25 units from cannon | Weapon fire | 1 per shot |
| Trail Particles | Behind ship | Continuous movement | up to max_particles |

---

## Key Files Summary

| File | Responsibility |
|------|-----------------|
| `src/core.lua` | Initial game spawn, orchestration |
| `src/procedural.lua` | Template-based generation, spawn strategies |
| `src/ship_loader.lua` | Ship entity creation factory |
| `src/systems/destruction.lua` | Item drops, respawning, death effects |
| `src/systems/wreckage.lua` | Wreckage piece generation |
| `src/systems/debris.lua` | Debris particles |
| `src/turret_modules/*.lua` | Projectile spawning |
| `src/systems/trail.lua` | Trail particles |
| `src/systems/enemy_mining.lua` | Enemy laser spawning |

---

## Spawn Order (Game Startup)

1. Canvas entity created
2. Player pilot entity created
3. Turret modules loaded
4. Ship designs loaded
5. **Player drone created** (at 0,0)
6. Camera created
7. UI entity created
8. Starfield created
9. **Asteroid cluster spawned** (around 0,0)
10. **Asteroid line spawned** (across map)
11. **15 enemy ships spawned** (distributed across map)
12. Music starts playing

All entities are managed through the ECS system using `ECS.createEntity()` and `ECS.addComponent()`.
