-- Standard Combat Ship Design
-- A balanced combat ship that can be piloted by player or AI
-- Color is determined by controller type

return {
    name = "Standard Combat Ship",
    description = "A versatile combat ship with balanced performance",
    
    -- Visual design (sleek combat shape)
    polygon = {
        {x = 0, y = -10}, {x = 6, y = -4}, {x = 8, y = 3}, 
        {x = 6, y = 8}, {x = 0, y = 5}, {x = -6, y = 8}, 
        {x = -8, y = 3}, {x = -6, y = -4}
    },
    -- Color will be set based on controller (blue for player, red for AI)
    color = nil, -- Set dynamically
    collisionRadius = 8,
    
    -- Stats
    hull = {current = 100, max = 100},
    shield = nil, -- No shields yet
    
    -- Physics (identical for both player and AI)
    friction = 0.9999, -- Space has no air resistance, nearly 1.0 for realistic coasting
    mass = 15, -- Heavier combat ship (3x the starter drone)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "basic_cannon",
    -- Turret cooldowns are defined per turret module (COOLDOWN), not in ship designs.
    defensiveSlots = 1,
    cargoCapacity = 10, -- Only used for player
    
    -- Abilities
    hasTrail = true, -- Both have engine trails
    
    -- AI settings (only used when AI-controlled)
    aiType = "patrol",
    patrolPoints = {{x=300,y=-200},{x=500,y=-300}},
    detectionRange = 400,
    engageRange = 240,
    patrolSpeed = 60
}
