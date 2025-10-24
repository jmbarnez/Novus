-- Starter Drone Ship Design
-- The player's initial lightweight ship with minimal armor

return {
    name = "Starter Drone",
    description = "A lightweight starter drone - fast and agile but fragile",

    -- Visual design (regular hexagon)
    polygon = {
        -- Top
        {x = 0,     y = -12},
        -- Upper right
        {x = 10.39, y = -6},
        -- Lower right
        {x = 10.39, y = 6},
        -- Bottom
        {x = 0,     y = 12},
        -- Lower left
        {x = -10.39, y = 6},
        -- Upper left
        {x = -10.39, y = -6},
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
            {x1 = 0, y1 = -12, x2 = 0, y2 = 10.5, color = {0.7, 0.9, 1, 0.4}}, -- Center accent stripe
            {x1 = 4.5, y1 = -7.5, x2 = 3, y2 = 9, color = {0.3, 0.8, 1, 0.3}}, -- Right accent
            {x1 = -4.5, y1 = -7.5, x2 = -3, y2 = 9, color = {0.3, 0.8, 1, 0.3}}, -- Left accent
        },
        cockpit = {
            {x = 0, y = -8.25, r = 1.8, color = {0.15, 0.15, 0.22, 1}}, -- Cockpit dome
        },
        engineGlow = {
            {x = 3, y = 9, r = 1.05, color = {0.3, 0.8, 1, 0.7}}, -- Right engine glow
            {x = -3, y = 9, r = 1.05, color = {0.3, 0.8, 1, 0.7}}, -- Left engine glow
        }
    },
    collisionRadius = 9,

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
