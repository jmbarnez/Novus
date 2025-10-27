-- Red Scout Ship Design
-- Fast, light attack ship used by enemy AI
-- Same base stats as Starter Drone

return {
    name = "Red Scout",
    description = "A small, fast attack ship with light armor",
    
    -- Visual design (equilateral triangle)
    polygon = {
        -- Side length = 16, height = side * sqrt(3)/2
        -- Centroid at origin: top vertex y = -2/3*height, base vertices y = 1/3*height
        { x = 0,             y = -2 * (16 * math.sqrt(3) / 2) / 3 },
        { x = 16 / 2,        y = (16 * math.sqrt(3) / 2) / 3 },
        { x = -16 / 2,       y = (16 * math.sqrt(3) / 2) / 3 },
    cockpitOffsetX = 0,
    cockpitOffsetY = -(16 * math.sqrt(3) / 2) * 0.2,
    cockpitRadius = 4,
    -- Position turret slightly forward toward the triangle tip
    turretOffsetX = 0,
    turretOffsetY = -(16 * math.sqrt(3) / 2) * 0.25,
    -- rotation can be set per-design (in radians) to rotate the whole polygon
    rotation = 0,
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
    mass = 20, -- Reduced for better acceleration (asteroids are 200-1800)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)
    thrustForce = 2000, -- Greatly increased thrust for high acceleration
    -- Explicit max speed for UI/stats
    maxSpeed = 250,
    
    -- Equipment
    turretSlots = 1,
    defaultTurret = "",  -- No default; turret will be set dynamically by spawning logic
    defensiveSlots = 1,
    cargoCapacity = 2.0, -- Small scout ship: 2 m³ cargo capacity
    
    -- Abilities
    hasTrail = true,
    
    -- AI settings (only used when AI-controlled)
    aiType = "patrol",
    patrolPoints = {},  -- Empty patrol points - AI will wander randomly
    detectionRange = 800,
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
