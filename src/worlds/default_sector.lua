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
        -- Enemy type definitions: {enemyType = count}
        types = {
            ["red_scout"] = 10,
        },
        -- Weapon assignments - only basic_cannon for combat enemies
        weapons = {
            ["red_scout"] = "basic_cannon"
        },
        -- AI behavior settings
        aiType = "combat",
        aiState = "patrol",
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
    
    -- Stations (custom static objects)
    stations = {
        {
            x = 0, y = 0, size = 100, mass = 1200,
            color = {0.79, 0.85, 1, 1},
            detail = {
                hullSides = 12,
                hullRadius = 115,
                hullRotation = math.pi / 12,
                hullColor = {0.68, 0.78, 1, 1},
                collidableRadius = 125,
                disableQuestionMark = true,
                modules = {
                    { type = "core_glow", radius = 40, color = {0.98, 1, 1, 0.32} },
                    { type = "disc", radius = 34, color = {0.94, 0.96, 1, 0.42} },
                    { type = "ring", radius = 72, width = 14, color = {0.55, 0.7, 1, 0.4} },
                    { type = "spokes", count = 8, innerRadius = 28, outerRadius = 98, width = 9, color = {0.8, 0.88, 1, 0.28} },
                    { type = "panels", count = 6, radius = 148, width = 68, height = 20, color = {0.26, 0.68, 1, 0.46} },
                    { type = "arms", count = 3, radius = 124, length = 58, width = 16, capRadius = 10, capOffset = 38, color = {0.74, 0.86, 1, 0.36} },
                    { type = "pods", count = 6, radius = 176, sides = 6, podRadius = 16, rotationOffset = math.pi / 6, color = {0.78, 0.92, 1, 0.55}, glow = { radius = 20, color = {0.8, 0.95, 1, 0.3} } },
                    { type = "lights", count = 18, radius = 132, size = 5, color = {0.95, 0.98, 1, 0.42} },
                    { type = "dish", radius = 84, width = 4, startAngle = -0.35, endAngle = 0.35, spinSpeed = 1.1, mastLength = 28, mastWidth = 6, mastAngle = 0.08, color = {0.88, 0.94, 1, 0.62}, mastColor = {0.74, 0.82, 1, 0.6}, capRadius = 10, capColor = {0.95, 1, 1, 0.5} },
                    { type = "antenna", angle = -0.4, length = 92, width = 2, color = {0.9, 0.95, 1, 0.7} },
                    { type = "shield", radius = 190, color = {0.5, 0.72, 1, 0.18} }
                }
            },
            label = "Orion Port"
        }
    }
}

