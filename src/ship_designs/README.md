# Ship Designs

This directory contains modular ship design files. Each ship design is a Lua module that returns a configuration table.

## Creating a New Ship Design

Create a new `.lua` file in this directory with the following structure:

```lua
return {
    -- Display info
    name = "Ship Name",
    description = "Description of the ship",
    
    -- Visual design (polygon vertices)
    polygon = {
        {x = 0, y = -10}, {x = 8, y = -5}, -- etc.
    },
    color = {r, g, b, a}, -- RGBA values (0-1), or nil for auto-color
    collisionRadius = 10, -- Bounding circle radius
    
    -- Stats
    hull = {current = 100, max = 100},
    shield = {current = 50, max = 50, regenRate = 5, regenDelay = 3}, -- Optional
    durability = {current = 100, max = 100}, -- For destructible entities (enemies)
    
    -- Physics
    friction = 0.95, -- 0-1, higher = more friction
    maxSpeed = 300,
    mass = 1,
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "basic_cannon", -- Optional, turret module ID
  -- Turret cooldowns are defined ONLY by turret modules (e.g., `src/turret_modules/basic_cannon.lua`) using the `COOLDOWN` field. Never define cooldowns in ship designs.
    cargoCapacity = 2.5, -- Cargo capacity in cubic meters m3 (all ships have cargo)
    
    -- Abilities (optional)
    hasTrail = true, -- Engine trail effect
    hasMagnet = true, -- Item collection
    magnetRadius = 200,
    magnetPullSpeed = 120,
    magnetMaxItems = 24,
    
    -- AI settings (only used when AI-controlled)
    aiType = "patrol", -- "patrol", "guard", "aggressive", etc.
    patrolPoints = {{x=0,y=0}, {x=100,y=100}},
    detectionRange = 400,
    engageRange = 240,
    patrolSpeed = 60
}
```

## Loading Drones

Drones are loaded automatically at startup. To add a new drone:

1. Create the drone design file (e.g., `my_drone.lua`)
2. Add the design ID to the `knownDesigns` list in `src/drone_loader.lua`
3. Use `DroneLoader.createDrone("my_drone", x, y, controllerType, controllerId)` to spawn

## Controller Types

- `"player"` - Player-controlled drone (requires pilot entity ID)
  - Auto-colored **blue** if design.color is nil
- `"ai"` - AI-controlled drone (uses aiType and AI settings from design)
  - Auto-colored **red** if design.color is nil
- `nil` - Uncontrolled drone (physics only)
  - Auto-colored **gray** if design.color is nil

**Note:** If a design specifies a color, it will always use that color regardless of controller type. Set `color = nil` to enable automatic team-based coloring.

## Example Usage

```lua
-- Create a player drone
local pilotId = ... -- pilot entity ID
local droneId = DroneLoader.createDrone("starter_hexagon", 0, 0, "player", pilotId)

-- Create an AI enemy drone
local enemyId = DroneLoader.createDrone("red_scout", 300, -200, "ai")
```

## Existing Drones

- **starter_hexagon** - Default player drone, hexagonal shape, balanced stats
- **red_scout** - Small, fast enemy drone with light armor
