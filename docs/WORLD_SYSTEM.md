# World/Sector System

A modular system for creating and loading different sectors of space with procedurally generated content.

## Overview

The world system allows you to design different sectors by defining asteroid clusters, enemy spawns, visual themes, and gameplay features in simple Lua configuration files.

## Architecture

### Components

1. **`src/world_loader.lua`** - Core world loading system
   - Loads world definitions from files
   - Initializes asteroid clusters
   - Spawns enemies according to configuration
   - Manages world state

2. **`src/worlds/`** - World definition folder
   - Contains individual sector files
   - Each file defines a complete world configuration
   - Easy to add new sectors

3. **Integration** - Modified `src/game_init.lua`
   - Loads world definitions at startup
   - Initializes selected world
   - Single line to change which sector loads

## Creating a New Sector

Create a new `.lua` file in `src/worlds/`:

```lua
return {
    name = "Your Sector Name",
    description = "What makes this sector unique",
    
    seed = nil,  -- Random seed (nil = random each time)
    
    asteroidClusters = {
        count = 3,
        clusters = {
            {x = 1000, y = 0, radius = 600, maxAsteroids = 30},
            {x = -2000, y = 500, radius = 500, maxAsteroids = 25},
            {x = 2000, y = -500, radius = 700, maxAsteroids = 35}
        }
    },
    
    enemies = {
        types = {
            ["red_scout"] = 5,
            ["heavy_drone"] = 2
        },
        weapons = {
            ["red_scout"] = "basic_cannon",
            ["heavy_drone"] = "combat_laser"
        },
        aiType = "combat",
        aiState = "patrol"
    },
    
    theme = {
        background = {0.01, 0.01, 0.02},
        starDensity = "normal",
        nebulaEnabled = false
    },
    
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = true
    }
}
```

## Included Worlds

### `default_sector.lua`
- Balanced gameplay sector
- 1 asteroid cluster with 30 asteroids
- 5 enemy patrols
- Standard difficulty

### `asteroid_field.lua`
- Dense asteroid field
- 5 asteroid clusters with 30-40 asteroids each
- Minimal enemies (2 mining drones)
- Mining-focused gameplay

### `mining_zone.lua`
- Peaceful mining sector
- 3 large asteroid clusters
- Mining-focused enemies
- Resource gathering paradise

### `combat_sector.lua`
- High-danger combat zone
- Minimal asteroids (15)
- Heavy enemy presence (10 red scouts + 2 heavy drones)
- Combat-focused gameplay

## Using Worlds

### Loading a World

In `src/game_init.lua`, change the world ID:

```lua
-- Initialize world/sector (loads asteroids and enemies)
WorldLoader.initWorld("default_sector")  -- Change this!
```

### World Names

Available worlds:
- `"default_sector"` - Standard balanced sector
- `"asteroid_field"` - Dense asteroid field
- `"mining_zone"` - Peaceful mining zone
- `"combat_sector"` - High-difficulty combat zone

## World Configuration Options

### Metadata
- `name` - Display name for the sector
- `description` - Brief description
- `seed` - Random seed (nil = randomize)

### Asteroid Clusters
- `count` - Number of clusters
- `clusters` - Array of cluster configs
  - `x`, `y` - Cluster center position
  - `radius` - Cluster radius
  - `maxAsteroids` - Asteroids per cluster

### Enemies
- `types` - Enemy type and count
- `weapons` - Weapon per enemy type
- `aiType` - Overall AI behavior
- `aiState` - Initial AI state

### Theme
- `background` - RGB space color
- `starDensity` - Starfield density
- `nebulaEnabled` - Nebula effects

### Features
- `salvageEnabled` - Enable salvaging
- `miningEnabled` - Enable mining
- `combatEnabled` - Enable combat

## World Coordinates

World spans:
- X: -4000 to 4000
- Y: -2000 to 2000
- Player spawns at: (-1500, 0)

## Design Tips

1. **Cluster Placement**: Keep clusters away from spawn point (-1500, 0)
2. **Resource Balance**: Balance asteroids vs enemies for gameplay
3. **Theme Consistency**: Match visual theme to gameplay focus
4. **Enemy Variety**: Mix enemy types and weapons
5. **Seed Reproducibility**: Set seed for consistent generation

## Advanced Usage

### Procedural Generation

World definitions support:
- Fixed positions (x, y coordinates)
- Random positions (omit x/y)
- Custom cluster sizes and counts
- Mixed asteroid densities

### Dynamic Worlds

Future enhancements:
- Multi-sector maps
- Sector transitions
- Dynamic enemy spawning
- World-specific events

## File Structure

```
src/
├── world_loader.lua      # Core world loading system
└── worlds/               # World definitions
    ├── README.md         # World creation guide
    ├── default_sector.lua
    ├── asteroid_field.lua
    ├── mining_zone.lua
    └── combat_sector.lua
```

## Integration

The world system integrates with:
- `ShipLoader` - Enemy ship spawning
- `AsteroidClusters` - Asteroid management
- `GameInit` - Game initialization
- Procedural generation system

## Future Expansion

Potential additions:
- Sector transitions/portals
- Dynamic sector loading
- Persistent sector state
- Sector-specific objectives
- Sector reputation systems
- Procedural sector generation

