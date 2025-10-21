-- Red Scout Ship Design
-- Fast, light attack ship used by enemy AI
-- Same base stats as Starter Drone

return {
    name = "Red Scout",
    description = "A small, fast attack ship with light armor",
    
    -- Visual design
    polygon = {
        -- Nose and cockpit
        {x = 0, y = -8},
        {x = 1.2, y = -6.5},
        {x = 2.2, y = -5.5},
        {x = 0.8, y = -4.5},
        -- Left forward fin
        {x = 3.2, y = -4.2},
        {x = 4.5, y = -2.5},
        {x = 4.2, y = -1.2},
        -- Left mid-body detail
        {x = 3.8, y = 0.2},
        {x = 4.2, y = 1.5},
        {x = 3.2, y = 3.2},
        {x = 2.2, y = 4.5},
        {x = 1.2, y = 6.2},
        -- Left rear engine pod
        {x = 2.8, y = 7.2},
        {x = 1.2, y = 7.8},
        {x = 0, y = 7.5},
        -- Right rear engine pod
        {x = -1.2, y = 7.8},
        {x = -2.8, y = 7.2},
        {x = -1.2, y = 6.2},
        {x = -2.2, y = 4.5},
        {x = -3.2, y = 3.2},
        {x = -4.2, y = 1.5},
        {x = -3.8, y = 0.2},
        -- Right mid-body detail
        {x = -4.2, y = -1.2},
        {x = -4.5, y = -2.5},
        {x = -3.2, y = -4.2},
        {x = -0.8, y = -4.5},
        {x = -2.2, y = -5.5},
        {x = -1.2, y = -6.5},
    },
    -- Color layers for texture and detail
    colors = {
        base = {1, 0.15, 0.15, 1},         -- Main red hull
        cockpit = {0.15, 0.15, 0.22, 1},    -- Dark blue/gray cockpit
        fins = {0.8, 0.2, 0.2, 1},         -- Lighter red for fins
        engine = {0.7, 0.7, 0.7, 1},       -- Silver/gray engine pods
        accent = {1, 0.7, 0.2, 1},         -- Orange/gold accent
    },
    texture = {
        stripes = {
            {x1 = 0, y1 = -8, x2 = 0, y2 = 7.5, color = {1, 0.7, 0.2, 0.5}}, -- Center stripe
            {x1 = 2.2, y1 = -5.5, x2 = 2.2, y2 = 4.5, color = {0.8, 0.2, 0.2, 0.4}}, -- Left stripe
            {x1 = -2.2, y1 = -5.5, x2 = -2.2, y2 = 4.5, color = {0.8, 0.2, 0.2, 0.4}}, -- Right stripe
        },
        cockpit = {
            {x = 0, y = -7, r = 1.2, color = {0.15, 0.15, 0.22, 1}}, -- Cockpit dome
        },
        engineGlow = {
            {x = 2.8, y = 7.2, r = 0.7, color = {0.7, 0.7, 1, 0.7}}, -- Left engine glow
            {x = -2.8, y = 7.2, r = 0.7, color = {0.7, 0.7, 1, 0.7}}, -- Right engine glow
        }
    },
    collisionRadius = 6,
    
    -- Stats (same as starter drone)
    hull = {current = 60, max = 60},
    shield = nil,
    
    -- Physics (same as starter drone)
    friction = 0.9999, -- Space has no air resistance, nearly 1.0 for realistic coasting
    mass = 5, -- Very light for a ship (projectiles are 0.5, asteroids are 50-500)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "",  -- No default; turret will be set dynamically by spawning logic
    defensiveSlots = 1,
    cargoCapacity = 10,
    
    -- Abilities
    hasTrail = true,
    
    -- AI settings (only used when AI-controlled)
    aiType = "patrol",
    patrolPoints = {},  -- Empty patrol points - AI will wander randomly
    detectionRange = 400,
    engageRange = 240,
    patrolSpeed = 60
}
