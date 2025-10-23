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
            ["red_scout"] = 2
        },
        
        -- Weapon assignments per enemy type
        weapons = {
            ["red_scout"] = "basic_cannon"
        },
        
        -- AI behavior settings
        aiType = "combat",
        aiState = "patrol"
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
    }
}

