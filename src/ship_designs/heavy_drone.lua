-- Heavy Drone Ship Design
-- A larger, heavily armored drone variant with built-in shield
-- 4x the size of the Starter Drone with significant improvements to hull and mass

return {
    name = "Heavy Drone",
    description = "A heavily armored drone with integrated shield - slow but durable",

    -- Visual design (symmetrical octagon - scaled 4x from starter drone)
    polygon = {
        -- Widened octagon for a more even/frigate silhouette
        {x = 0,    y = -36},   -- Top
        {x = 34,   y = -20},   -- Upper right
        {x = 40,   y = 0},     -- Right
        {x = 34,   y = 20},    -- Lower right
        {x = 0,    y = 36},    -- Bottom
        {x = -34,  y = 20},    -- Lower left
        {x = -40,  y = 0},     -- Left
        {x = -34,  y = -20},   -- Upper left
    },
    colors = {
        base = {1, 0.15, 0.15, 1},         -- Main red hull
        stripes = {1, 0.15, 0.15, 1},      -- Red stripes
        cockpit = {0.15, 0.15, 0.22, 1},   -- Dark cockpit
        accent = {1, 0.7, 0.2, 1},         -- Gold accent
        engine = {0.7, 0.7, 0.7, 1},       -- Silver engine
        glow = {0.7, 0.7, 1, 0.7},         -- Blue glow
        shield = {0.2, 0.8, 0.9, 0.3},     -- Cyan shield
        shadow = {0.5, 0.05, 0.05, 0.7},   -- Dark red shadow
        panel = {0.8, 0.2, 0.2, 0.5},      -- Panel lines
        sensor = {0.7, 0.7, 1, 0.8},       -- Sensor domes
        antenna = {0.9, 0.9, 0.9, 0.7},    -- Antenna
    },
    texture = {
        stripes = {
            -- Center accent stripe (orange)
            {x1 = 0, y1 = -32, x2 = 0, y2 = 28, color = {1, 0.7, 0.2, 0.7}},
            -- Flanking red stripes
            {x1 = 10, y1 = -28, x2 = 9, y2 = 24, color = {1, 0.2, 0.2, 0.5}},
            {x1 = -10, y1 = -28, x2 = -9, y2 = 24, color = {1, 0.2, 0.2, 0.5}},
            -- Diagonal gold accents
            {x1 = 16, y1 = -20, x2 = 8, y2 = 0, color = {1, 0.7, 0.2, 0.5}},
            {x1 = -16, y1 = -20, x2 = -8, y2 = 0, color = {1, 0.7, 0.2, 0.5}},
            -- Panel lines
            {x1 = 0, y1 = -16, x2 = 0, y2 = 16, color = {0.8, 0.2, 0.2, 0.4}, lineWidth = 2},
            {x1 = 12, y1 = -8, x2 = 12, y2 = 8, color = {0.8, 0.2, 0.2, 0.3}, lineWidth = 2},
            {x1 = -12, y1 = -8, x2 = -12, y2 = 8, color = {0.8, 0.2, 0.2, 0.3}, lineWidth = 2},
            -- Top antenna detail
            {x1 = 0, y1 = -32, x2 = 0, y2 = -42, color = {0.9, 0.9, 0.9, 0.8}, lineWidth = 2},
            {x1 = 3, y1 = -32, x2 = 3, y2 = -38, color = {0.7, 0.7, 1, 0.6}, lineWidth = 2},
            {x1 = -3, y1 = -32, x2 = -3, y2 = -38, color = {0.7, 0.7, 1, 0.6}, lineWidth = 2},
        },
        cockpit = {
            -- Main cockpit dome
            {x = 0, y = -22, r = 5.2, color = {0.15, 0.15, 0.22, 1}},
            -- Extra sensor domes
            {x = 6, y = -28, r = 2.2, color = {0.7, 0.7, 1, 0.8}},
            {x = -6, y = -28, r = 2.2, color = {0.7, 0.7, 1, 0.8}},
            {x = 4, y = -24, r = 1.5, color = {1, 0.7, 0.2, 0.7}},
            {x = -4, y = -24, r = 1.5, color = {1, 0.7, 0.2, 0.7}},
            -- Red highlight on cockpit
            {x = 0, y = -20, r = 2.8, color = {1, 0.2, 0.2, 0.4}},
        },
        engineGlow = {
            {x = 8, y = 24, r = 3.2, color = {0.7, 0.7, 1, 0.8}}, -- Right engine glow
            {x = -8, y = 24, r = 3.2, color = {0.7, 0.7, 1, 0.8}}, -- Left engine glow
            -- Extra engine glow details
            {x = 0, y = 28, r = 2.2, color = {1, 0.7, 0.2, 0.6}},
            -- Thruster glows
            {x = 16, y = 20, r = 1.2, color = {1, 0.7, 0.2, 0.5}},
            {x = -16, y = 20, r = 1.2, color = {1, 0.7, 0.2, 0.5}},
        },
        -- Black panel accents and shadow lines for depth
        panels = {
            {x1 = -20, y1 = -4, x2 = 20, y2 = -4, color = {0,0,0,0.6}, lineWidth = 3},
            {x1 = -18, y1 = 4, x2 = 18, y2 = 4, color = {0,0,0,0.5}, lineWidth = 2},
            {x = 0, y = 8, r = 10, color = {0,0,0,0.18}}, -- subtle dark belly shadow
        },
        sensors = {
            {x = 10, y = -30, r = 1.2, color = {0.7, 0.7, 1, 0.7}},
            {x = -10, y = -30, r = 1.2, color = {0.7, 0.7, 1, 0.7}},
            {x = 0, y = -36, r = 1.5, color = {1, 0.7, 0.2, 0.6}},
        },
        shadow = {
            {x = 0, y = 8, r = 18, color = {0.5, 0.05, 0.05, 0.25}},
        },
    },
    collisionRadius = 24,

    -- Stats (heavily armored with integrated shield)
    hull = {current = 200, max = 200},
    shield = {current = 50, max = 50, regenRate = 3, regenDelay = 2},

    -- Physics (heavy and slow)
    friction = 0.9999, -- Space has no air resistance, nearly 1.0 for realistic coasting
    mass = 80, -- Much heavier (16x mass of starter drone - scales with volume/4x³)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)

    -- Equipment
    turretSlots = 2,
    defaultTurret = "",
    defensiveSlots = 1,
    cargoCapacity = 50,

    -- Abilities
    hasTrail = true
    ,
    -- Per-ship turret configuration: make heavy drone turrets larger and more prominent
    turret = {
        enabled = true,
        scale = 1.6,
        overhang = 8
    }
}
