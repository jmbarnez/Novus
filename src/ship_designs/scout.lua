---@diagnostic disable: undefined-global
-- Scout Ship Design - Small autonomous collector with magnetic field
-- Scouts roam the map collecting resource bits

return {
    name = "Scout",
    description = "Small autonomous collector ship with built-in magnetic field. Roams freely collecting resources.",
    
    -- Collision and Physics
    collisionRadius = 15,
    mass = 0.5,
    friction = 0.95,
    
    -- Hull and Shield
    hull = {
        current = 25,
        max = 25
    },
    -- No shield for scouts (cheap, expendable)
    
    -- Visual
    color = {0.3, 1, 0.3, 1},  -- Bright green
    
    -- Polygon shape - small triangle
    polygon = {
        {x = 0, y = -12},
        {x = 10, y = 10},
        {x = -10, y = 10}
    },
    
    -- No turrets (scouts don't fight)
    turretSlots = 0,
    
    -- No defensive slots
    defensiveSlots = 0,
    
    -- Cargo for collecting bits
    cargoCapacity = 50,
    
    -- AI behavior
    aiType = "scout",
    patrolSpeed = 150,
    detectionRange = 400,
    engageRange = 0,  -- Scouts don't engage
    
    -- Trail
    hasTrail = true
}
