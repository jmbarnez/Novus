# World/Sector Definitions

This folder contains world definitions for different sectors of space. Each world file defines:
- Asteroid cluster locations and counts
- Enemy spawns and configurations
- Visual themes
- Special features

## Creating a New World

Create a new `.lua` file in this folder following this template:

```lua
return {
    -- World metadata
    name = "Your Sector Name",
    description = "Brief description of the sector",
    
    -- Procedural generation seed (nil = random each time)
    seed = nil,
    
    -- Asteroid clusters configuration
    asteroidClusters = {
        count = 1,  -- Number of clusters
        clusters = {
            {
                x = 1000,          -- Cluster center X position
                y = 0,             -- Cluster center Y position
                radius = 600,      -- Cluster radius
                maxAsteroids = 30  -- Asteroids per cluster
            }
            -- Add more clusters here...
        }
    },
    
    -- Enemy configuration
    enemies = {
        -- Enemy type definitions: {enemyType = count}
        types = {
            ["red_scout"] = 5,     -- Spawn 5 red scouts
            ["heavy_drone"] = 2    -- Spawn 2 heavy drones
        },
        
        -- Weapon assignments per enemy type
        weapons = {
            ["red_scout"] = "basic_cannon",
            ["heavy_drone"] = "continuous_beam"
        },
        
        -- AI behavior settings
        aiType = "combat",      -- "combat" or "mining"
        aiState = "patrol"      -- "patrol", "mining", etc.
    },
    
    -- Visual theme
    theme = {
        background = {0.01, 0.01, 0.02},  -- RGB space color
        starDensity = "normal",            -- "sparse", "normal", "dense"
        nebulaEnabled = false              -- Enable nebula effects
    },
    
    -- Special features
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = true
    }
}
```

## Example Worlds

### `default_sector.lua`
Standard balanced sector with moderate asteroids and enemies.

### `asteroid_field.lua`
Dense asteroid field with abundant resources. Few enemies.

### `mining_zone.lua`
Peaceful sector focused on resource gathering. Mining-focused enemies.

### `combat_sector.lua`
Dangerous sector with few asteroids but many enemy patrols.

## Using Worlds

In your game initialization, load and activate a world:

```lua
local WorldLoader = require('src.world_loader')

-- Load all world definitions
WorldLoader.loadAllWorlds("src.worlds")

-- Initialize a specific world
WorldLoader.initWorld("asteroid_field")
```

## World Properties

### Asteroid Clusters
- `count`: Number of asteroid clusters
- `clusters`: Array of cluster configurations
  - `x`, `y`: Cluster center position
  - `radius`: Radius of the cluster
  - `maxAsteroids`: Asteroids per cluster

### Enemies
- `types`: Table mapping enemy type to spawn count
- `weapons`: Table mapping enemy type to weapon module
- `aiType`: Overall AI behavior ("combat" or "mining")
- `aiState`: Initial AI state

### Theme
- `background`: RGB color for space background `{r, g, b}`
- `starDensity`: Starfield density ("sparse", "normal", "dense")
- `nebulaEnabled`: Enable nebula visual effects

### Features
Control which gameplay systems are active:
- `salvageEnabled`: Allow salvaging wreckage
- `miningEnabled`: Allow mining asteroids
- `combatEnabled`: Enable combat interactions

## Tips

1. **Seed for reproducibility**: Set `seed` to a number for consistent generation
2. **Cluster placement**: Keep clusters away from spawn point (0, 0)
3. **Balanced worlds**: Balance asteroids vs enemies for gameplay
4. **Thematic consistency**: Match visual theme to gameplay focus
5. **Enemy variety**: Mix different enemy types and weapons

## World Coordinates

The game world spans from:
- X: `-4000` to `4000`
- Y: `-2000` to `2000`

Player spawns at approximately `(-1500, 0)`.

