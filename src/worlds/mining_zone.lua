-- Mining Zone World Definition
-- Peaceful sector focused on resource gathering

return {
    name = "Stardust Mining Zone",
    description = "Asteroid-rich sector perfect for mining operations",
    
    seed = nil,
    
    asteroidClusters = {
        count = 3,
        clusters = {
            {
                x = 0,
                y = 0,
                radius = 500,
                maxAsteroids = 50
            },
            {
                x = -1500,
                y = -1000,
                radius = 600,
                maxAsteroids = 45
            },
            {
                x = 1500,
                y = 1000,
                radius = 550,
                maxAsteroids = 48
            }
        }
    },
    
    enemies = {
        types = {
            ["red_scout"] = 3
        },
        weapons = {
            ["red_scout"] = "mining_laser"
        },
        aiType = "mining",
        aiState = "mining"
    },
    
    theme = {
        background = {0.05, 0.15, 0.22},  -- Blue-tinted navy for mining zone
        starDensity = "dense",
        nebulaEnabled = false
    },
    
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = false
    }
}

