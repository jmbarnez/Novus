-- Asteroid Field World Definition
-- Dense asteroid field with abundant resources but few enemies

return {
    name = "The Belt",
    description = "Dense asteroid field rich in minerals",
    
    seed = nil,
    
    asteroidClusters = {
        count = 5,
        clusters = {
            {
                x = -2000,
                y = -500,
                radius = 800,
                maxAsteroids = 40
            },
            {
                x = 500,
                y = 1000,
                radius = 700,
                maxAsteroids = 35
            },
            {
                x = 2500,
                y = -800,
                radius = 750,
                maxAsteroids = 38
            },
            {
                x = -1500,
                y = 1500,
                radius = 600,
                maxAsteroids = 30
            },
            {
                x = 3000,
                y = 800,
                radius = 650,
                maxAsteroids = 32
            }
        }
    },
    
    enemies = {
        types = {
            ["red_scout"] = 2
        },
        weapons = {
            ["red_scout"] = "mining_laser"
        },
        aiType = "mining",
        aiState = "mining"
    },
    
    theme = {
        background = {0.01, 0.01, 0.04},
        starDensity = "sparse",
        nebulaEnabled = false
    },
    
    features = {
        salvageEnabled = true,
        miningEnabled = true,
        combatEnabled = false
    }
}

