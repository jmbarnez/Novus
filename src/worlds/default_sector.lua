-- Default Sector World Definition
-- Standard gameplay sector with balanced asteroid and enemy distribution

return {
    -- World metadata
    name = "Alpha Sector",
    description = "Standard sector with balanced resources and moderate danger",
    
    -- Procedural generation seed (nil = random each time)
    seed = nil,
    
    -- Asteroid clusters configuration
    -- Multiple clusters placed around the sector so enemies spawn around them
    asteroidClusters = {
        count = 3,
        clusters = {
            {
                x = 2500,            -- Cluster center X (scaled for smaller world)
                y = 0,               -- Cluster center Y
                radius = 1500,       -- Cluster radius (scaled)
                maxAsteroids = 40    -- Asteroids per cluster
            },
            {
                x = -3500,           -- Cluster center X (scaled)
                y = 2000,            -- Cluster center Y (scaled)
                radius = 1250,       -- Cluster radius (scaled)
                maxAsteroids = 30
            },
            {
                x = 6000,            -- Cluster center X (scaled)
                y = -2500,           -- Cluster center Y (scaled)
                radius = 1750,       -- Cluster radius (scaled)
                maxAsteroids = 50
            }
        }
    },
    
    -- Enemy configuration
    enemies = {
        -- Enemy groups with different AI types
        groups = {
            {
                -- Combat red scouts with cannons (half of enemies)
                types = { ["red_scout"] = 10 },
                weapons = { ["red_scout"] = "basic_cannon" },
                aiType = "combat",
                aiState = "patrol",
            },
            {
                -- Mining red scouts with continuous beams (half of enemies)
                types = { ["red_scout"] = 10 },
                weapons = { ["red_scout"] = "continuous_beam" },
                aiType = "mining",
                aiState = "mining",
            }
        }
    },
    
    -- Visual theme
    theme = {
    background = {0.08, 0.12, 0.25, 1},  -- Navy blue space color (opaque)
        starDensity = "normal",
        nebulaEnabled = false
    },
    
    -- Special features
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = true
    },
    
    -- Stations (custom static objects) - simplified: reference a prefab from src/world_objects
    stations = {
        {
            prefab = "station",
            x = 0, y = 0,
            design = "quest_kiosk",
            size = 100,
            mass = 1200,
            color = {0.79, 0.85, 1, 1},
        }
    }
}

