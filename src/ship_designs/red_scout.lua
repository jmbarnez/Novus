-- Red Scout Ship Design
-- Fast, light attack ship used by enemy AI
-- Same base stats as Starter Drone

return {
    name = "Red Scout",
    description = "A small, fast attack ship with light armor",
    
    -- Visual design (circle)
    polygon = {
        -- Circle approximated with 16 vertices
        {x = 0,    y = -8},
        {x = 1.96, y = -7.76},
        {x = 3.70, y = -7.06},
        {x = 5.08, y = -5.91},
        {x = 6.06, y = -4.36},
        {x = 6.54, y = -2.59},
        {x = 6.49, y = -0.74},
        {x = 5.91, y = 1.17},
        {x = 4.81, y = 3.23},
        {x = 3.23, y = 4.81},
        {x = 1.17, y = 5.91},
        {x = -0.74, y = 6.49},
        {x = -2.59, y = 6.54},
        {x = -4.36, y = 6.06},
        {x = -5.91, y = 5.08},
        {x = -7.06, y = 3.70},
        {x = -7.76, y = 1.96},
        {x = -8,    y = 0},
        {x = -7.76, y = -1.96},
        {x = -7.06, y = -3.70},
        {x = -5.91, y = -5.08},
        {x = -4.36, y = -6.06},
        {x = -2.59, y = -6.54},
        {x = -0.74, y = -6.49},
    },
    -- Color layers for texture and detail
    colors = {
        stripes = {1, 0.15, 0.15, 1},      -- Main red hull
        cockpit = {0.15, 0.15, 0.22, 1},   -- Dark blue/gray cockpit
        base = {1, 0.15, 0.15, 1},         -- Main red hull (legacy)
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
    thrustForce = 300, -- Base thrust force for AI movement (applies acceleration)
    
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
    detectionRange = 1600,
    engageRange = 240,
    patrolSpeed = 60,
    
    -- Variant-specific detection ranges
    miningDetectionRange = 600,
    combatDetectionRange = 800,
    
    -- AI behavioral parameters
    orbitDistance = 300,           -- Optimal distance to maintain when orbiting
    wanderRadius = 150,            -- How far to wander from spawn point
    wanderThrustMultiplier = 0.3,  -- Reduced thrust when wandering
    orbitThrustMultiplier = 0.7,   -- Reduced thrust when orbiting
    steeringResponsiveness = 0.3,  -- How quickly AI can change direction (0-1, lower = smoother turns)
}
