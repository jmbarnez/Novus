-- Combat Sector World Definition
-- Dangerous sector with few asteroids but lots of enemy patrols

return {
    name = "Danger Zone",
    description = "Highly contested sector - extreme danger",
    
    seed = nil,
    
    asteroidClusters = {
        count = 1,
        clusters = {
            {
                x = 1000,
                y = 0,
                radius = 400,
                maxAsteroids = 15
            }
        }
    },
    
    enemies = {
        types = {
            ["red_scout"] = 10,
            ["heavy_drone"] = 2
        },
        weapons = {
            ["red_scout"] = "combat_laser",
            ["heavy_drone"] = "combat_laser"
        },
        aiType = "combat",
        aiState = "patrol"
    },
    
    theme = {
        background = {0.02, 0.01, 0.01},
        starDensity = "sparse",
        nebulaEnabled = false
    },
    
    features = {
        salvageEnabled = true,
        miningEnabled = false,
        combatEnabled = true
    }
}

