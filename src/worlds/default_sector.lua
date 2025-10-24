-- Default Sector World Definition
-- Standard gameplay sector with balanced asteroid and enemy distribution

return {
    -- World metadata
    name = "Alpha Sector",
    description = "Standard sector with balanced resources and moderate danger",
    
    -- Procedural generation seed (nil = random each time)
    seed = nil,
    
    -- Asteroid clusters configuration
    asteroidClusters = {
        count = 1,
        clusters = {
            {
                x = 1000,            -- Cluster center X
                y = 0,                -- Cluster center Y
                radius = 600,         -- Cluster radius
                maxAsteroids = 30     -- Asteroids per cluster
            }
        }
    },
    
    -- Enemy configuration
    enemies = {
        -- Enemy type definitions: {enemyType = count}
        types = {
            ["red_scout"] = 10,
        },
        -- Weapon assignments pool (both weapons valid for red_scout)
        weapons = {
            ["red_scout"] = {"basic_cannon", "mining_laser"}
        },
        -- AI behavior settings
        aiType = "combat",
        aiState = "patrol",
    },
    
    -- Visual theme
    theme = {
        background = {0.01, 0.01, 0.02},  -- Space color
        starDensity = "normal",
        nebulaEnabled = false
    },
    
    -- Special features
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = true
    },
    
    -- Stations (custom static objects)
    stations = {
        {
            x = -1800, y = 0, size = 100, mass = 1200,
            color = {0.79, 0.85, 1, 1},
            detail = {
                habitatRing = { radius = 60, color = {0.6, 0.6, 0.7, 1} },
                solarPanels = {
                    count = 4,
                    radius = 130,
                    width = 50,
                    height = 16,
                    color = {0.2, 0.7, 1, 0.38}
                },
                core = { radius = 35, color = {0.98,0.98,1,0.37} }
            },
            label = "Orion Port"
        }
    }
}

