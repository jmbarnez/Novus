-- Starter Drone Ship Design
-- The player's initial lightweight ship with minimal armor

return {
    name = "Starter Drone",
    description = "A lightweight starter drone - fast and agile but fragile",

    -- Visual design (symmetrical circular)
    polygon = {
        -- Top
        {x = 0,    y = -8},
        -- Upper right
        {x = 6.93, y = -4},
        -- Right
        {x = 8,    y = 0},
        -- Lower right
        {x = 6.93, y = 4},
        -- Bottom
        {x = 0,    y = 8},
        -- Lower left
        {x = -6.93, y = 4},
        -- Left
        {x = -8,   y = 0},
        -- Upper left
        {x = -6.93, y = -4},
    },
    colors = {
        base = {0.0, 0.6, 1, 1},         -- Main bright blue hull (legacy)
        stripes = {0.0, 0.6, 1, 1},      -- Explicit stripes layer used by renderer
        cockpit = {0.15, 0.15, 0.22, 1}, -- Dark blue/gray cockpit
        accent = {0.7, 0.9, 1, 1},       -- Light blue accent
        engine = {0.7, 0.7, 0.7, 1},     -- Silver/gray engine pods
        glow = {0.3, 0.8, 1, 0.7},       -- Cyan engine glow
    },
    texture = {
        stripes = {
            {x1 = 0, y1 = -8, x2 = 0, y2 = 7, color = {0.7, 0.9, 1, 0.4}}, -- Center accent stripe
            {x1 = 3, y1 = -5, x2 = 2, y2 = 6, color = {0.3, 0.8, 1, 0.3}}, -- Right accent
            {x1 = -3, y1 = -5, x2 = -2, y2 = 6, color = {0.3, 0.8, 1, 0.3}}, -- Left accent
        },
        cockpit = {
            {x = 0, y = -5.5, r = 1.2, color = {0.15, 0.15, 0.22, 1}}, -- Cockpit dome
        },
        engineGlow = {
            {x = 2, y = 6, r = 0.7, color = {0.3, 0.8, 1, 0.7}}, -- Right engine glow
            {x = -2, y = 6, r = 0.7, color = {0.3, 0.8, 1, 0.7}}, -- Left engine glow
        }
    },
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
    defensiveSlots = 1,
    generatorSlots = 1,
    cargoCapacity = 10,

    -- Abilities
    hasTrail = true
}
