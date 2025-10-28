-- Starter Drone Ship Design
-- A realistic small utility drone with practical design elements

return {
    name = "Starter Drone",
    description = "A compact utility drone with modular construction - fast and agile but lightly armored",

    -- Visual design (realistic small spacecraft geometry)
    -- Asymmetric design with sensor pod, main hull, and utility mounts
    polygon = {
        -- Top sensor pod (smaller, offset forward)
        {x = 0,     y = -20},
        -- Upper right hull (angled for aerodynamics in atmosphere transitions)
        {x = 16,    y = -10},
        -- Lower right thruster mount
        {x = 18,    y = 6},
        -- Bottom thruster array
        {x = 0,     y = 16},
        -- Lower left thruster mount
        {x = -18,   y = 6},
        -- Upper left hull
        {x = -16,   y = -10},
    },

    -- Bright and visible metallic color palette
    colors = {
        base = {0.7, 0.75, 0.85, 1},       -- Bright silver-gray main hull
        stripes = {0.55, 0.6, 0.7, 1},     -- Medium gray for paneling
        cockpit = {0.3, 0.4, 0.6, 1},      -- Bright blue tinted canopy
        accent = {0.8, 0.85, 0.95, 1},     -- Very light gray highlights
        engine = {0.4, 0.45, 0.55, 1},     -- Medium engine nacelles
        glow = {0.6, 0.8, 1, 0.9},         -- Bright blue-white thruster glow
        sensor = {0.9, 0.95, 1, 1},        -- Very bright sensor dome highlights
        panel = {0.3, 0.35, 0.45, 0.8},    -- Visible panel line shadows
        antenna = {0.95, 0.95, 1, 0.9},    -- Bright communication arrays
        warning = {1, 0.8, 0.2, 0.9},      -- Bright safety markings
    },

    -- Detailed surface textures for realistic appearance
    texture = {
        stripes = {
            -- Main hull panel lines (horizontal divisions)
            {x1 = -14, y1 = -6, x2 = 14, y2 = -6, color = {0.4, 0.45, 0.55, 0.7}, lineWidth = 3},
            {x1 = -12, y1 = 2, x2 = 12, y2 = 2, color = {0.3, 0.35, 0.45, 0.6}, lineWidth = 2.4},

            -- Vertical structural members
            {x1 = 0, y1 = -16, x2 = 0, y2 = 12, color = {0.8, 0.85, 0.95, 0.5}, lineWidth = 2},
            {x1 = 8, y1 = -8, x2 = 7, y2 = 4, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 2},
            {x1 = -8, y1 = -8, x2 = -7, y2 = 4, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 2},

            -- Safety markings and identification stripes
            {x1 = -4, y1 = -14, x2 = 4, y2 = -14, color = {1, 0.8, 0.2, 0.8}, lineWidth = 4},
            {x1 = 2, y1 = 8, x2 = 2, y2 = 12, color = {1, 0.8, 0.2, 0.7}, lineWidth = 3},
            {x1 = -2, y1 = 8, x2 = -2, y2 = 12, color = {1, 0.8, 0.2, 0.7}, lineWidth = 3},
        },

        cockpit = {
            -- Main pilot/sensor dome (larger, more prominent)
            {x = 0, y = -12, r = 4.4, color = {0.3, 0.4, 0.6, 1}},
            -- Sensor highlight ring
            {x = 0, y = -12, r = 3.6, color = {0.9, 0.95, 1, 0.6}},
            -- Internal detail dots (simulating sensor arrays)
            {x = 2, y = -11, r = 0.8, color = {0.9, 0.95, 1, 0.9}},
            {x = -2, y = -11, r = 0.8, color = {0.9, 0.95, 1, 0.9}},
        },

        -- Main thruster arrays (realistic ion/plasma drives)
        engineGlow = {
            {x = 6, y = 12, r = 2.4, color = {0.6, 0.8, 1, 0.9}},   -- Right main thruster
            {x = -6, y = 12, r = 2.4, color = {0.6, 0.8, 1, 0.9}},  -- Left main thruster
            -- Secondary maneuvering thrusters
            {x = 12, y = 4, r = 1.2, color = {0.7, 0.9, 1, 0.8}},
            {x = -12, y = 4, r = 1.2, color = {0.7, 0.9, 1, 0.8}},
        },

        -- Surface details and utility equipment
        panels = {
            -- Access panel outlines and shadows
            {x1 = -10, y1 = -4, x2 = -4, y2 = -4, color = {0,0,0,0.6}, lineWidth = 2},
            {x1 = 4, y1 = -4, x2 = 10, y2 = -4, color = {0,0,0,0.6}, lineWidth = 2},
            {x1 = -8, y1 = 4, x2 = 8, y2 = 4, color = {0,0,0,0.5}, lineWidth = 2},

            -- Hull plating shadows for depth
            {x = 0, y = 0, r = 12, color = {0,0,0,0.25}}, -- Central shadow
            {x = 8, y = -4, r = 6, color = {0,0,0,0.2}}, -- Right shadow
            {x = -8, y = -4, r = 6, color = {0,0,0,0.2}}, -- Left shadow
        },

        -- Communication and sensor arrays
        sensors = {
            {x = 0, y = -18, r = 1.6, color = {0.9, 0.95, 1, 1}},   -- Main sensor dome
            {x = 4, y = -16, r = 1, color = {0.95, 0.95, 1, 0.8}}, -- Navigation sensor
            {x = -4, y = -16, r = 1, color = {0.95, 0.95, 1, 0.8}}, -- Communication array
        },

        -- Antenna and utility mounts
        antenna = {
            {x1 = 0, y1 = -18, x2 = 0, y2 = -24, color = {0.95, 0.95, 1, 0.9}, lineWidth = 3}, -- Main antenna
            {x1 = 3, y1 = -16, x2 = 3, y2 = -20, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 2}, -- Secondary antenna
            {x1 = -3, y1 = -16, x2 = -3, y2 = -20, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 2}, -- Tertiary antenna
        },

        -- Warning and identification markings
        warning = {
            {x1 = -6, y1 = -12, x2 = -2, y2 = -12, color = {1, 0.8, 0.2, 0.9}, lineWidth = 4}, -- Left marking
            {x1 = 2, y1 = -12, x2 = 6, y2 = -12, color = {1, 0.8, 0.2, 0.9}, lineWidth = 4},  -- Right marking
        }
    },
    collisionRadius = 18,
    frontDirection = -math.pi/2, -- Front faces "right" (90 degrees counter-clockwise from up)
    turretConeAngle = math.pi/2, -- Turret can aim within 90 degrees (±45 degrees from front)

    -- Stats (light utility drone)
    hull = {current = 60, max = 60},
    shield = nil,

    -- Physics (light and responsive)
    friction = 0.99, -- Reduced friction for higher max speed while maintaining responsiveness
    mass = 50, -- Reduced for better acceleration (asteroids are 200-1800)
    angularDamping = 0.95, -- Ships damp rotation faster (more control)
    
    thrustForce = 6000, -- High thrust for responsive movement and high max speed
    -- Equipment (modular utility setup)
    turretSlots = 1,
    defaultTurret = "",
    defensiveSlots = 1,
    generatorSlots = 1,
    cargoCapacity = 5, -- Small utility drone: 5 cubic meters

    -- Abilities (utility drone features)
    hasTrail = true
}
