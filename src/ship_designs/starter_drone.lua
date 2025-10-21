-- Starter Drone Ship Design
-- The player's initial lightweight ship with minimal armor

return {
    name = "Starter Drone",
    description = "A lightweight starter drone - fast and agile but fragile",
    
    -- Visual design (small sleek shape)
    polygon = {
        {x = 0, y = -8}, {x = 5, y = -3}, {x = 6, y = 2}, 
        {x = 5, y = 6}, {x = 0, y = 4}, {x = -5, y = 6}, 
        {x = -6, y = 2}, {x = -5, y = -3}
    },
    -- Color will be set based on controller (blue for player)
    color = nil, -- Set dynamically
    collisionRadius = 6,
    
    -- Stats (fragile starter ship)
    hull = {current = 60, max = 60},
    shield = nil,
    
    -- Physics (very light and nimble)
    friction = 0.9999, -- Space has no air resistance, nearly 1.0 for realistic coasting
    mass = 5, -- Very light for a ship (projectiles are 0.5, asteroids are 50-500)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "",
    -- Turret cooldowns are defined per turret module (COOLDOWN), not in ship designs.
    defensiveSlots = 1,
    cargoCapacity = 10,
    
    -- Abilities
    hasTrail = true
}
