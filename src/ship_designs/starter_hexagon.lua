-- Starter Hexagon Ship Design
-- The basic starter ship with balanced stats

return {
    name = "Starter Hexagon",
    description = "A reliable hexagonal ship with balanced performance",
    
    -- Visual design
    polygon = {
        {x = 0, y = -10}, {x = 8.66, y = -5}, {x = 8.66, y = 5}, 
        {x = 0, y = 10}, {x = -8.66, y = 5}, {x = -8.66, y = -5}
    },
    color = {0.5, 0.5, 0.5, 1}, -- Gray
    collisionRadius = 10,
    
    -- Stats
    hull = {current = 100, max = 100},
    shield = nil, -- No shield for starter
    
    -- Physics
    friction = 0.98, -- High friction = less deceleration, more drift
    mass = 1,
    
    -- Equipment slots
    turretSlots = 1,
    cargoCapacity = 10,
    
    -- Abilities
    hasTrail = true,
    hasMagnet = true,
    magnetRadius = 200,
    magnetPullSpeed = 120,
    magnetMaxItems = 24
}
