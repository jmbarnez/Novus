-- Red Scout Ship Design
-- Fast, light attack ship used by enemy AI

return {
    name = "Red Scout",
    description = "A small, fast attack ship with light armor",
    
    -- Visual design
    polygon = {
        {x = 0, y = -7}, {x = 4, y = -3}, {x = 6, y = 1}, 
        {x = 4, y = 5}, {x = 0, y = 3}, {x = -4, y = 5}, 
        {x = -6, y = 1}, {x = -4, y = -3}
    },
    color = {1, 0.15, 0.15, 1}, -- Red
    collisionRadius = 6,
    
    -- Stats
    hull = {current = 35, max = 35},
    shield = nil,
    
    -- Physics
    friction = 0.98, -- High friction = less deceleration, more drift
    mass = 0.5,
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "basic_cannon",
    turretCooldown = 0.6,
    
    -- AI settings (only used when AI-controlled)
    aiType = "patrol",
    patrolPoints = {{x=300,y=-200},{x=500,y=-300}},
    detectionRange = 400,
    engageRange = 240,
    patrolSpeed = 60
}
