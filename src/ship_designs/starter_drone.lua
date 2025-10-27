-- Starter Drone Ship Design
-- A realistic small utility drone with practical design elements

return {
    name = "Starter Drone",
    description = "A compact utility drone with modular construction - fast and agile but lightly armored",

    -- Visual design (realistic small spacecraft geometry)
    -- Asymmetric design with sensor pod, main hull, and utility mounts
    polygon = {
        -- Top sensor pod (smaller, offset forward)
        {x = 0,     y = -10},
        -- Upper right hull (angled for aerodynamics in atmosphere transitions)
        {x = 8,     y = -5},
        -- Lower right thruster mount
        {x = 9,     y = 3},
        -- Bottom thruster array
        {x = 0,     y = 8},
        -- Lower left thruster mount
        {x = -9,    y = 3},
        -- Upper left hull
        {x = -8,    y = -5},
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
            {x1 = -7, y1 = -3, x2 = 7, y2 = -3, color = {0.4, 0.45, 0.55, 0.7}, lineWidth = 1.5},
            {x1 = -6, y1 = 1, x2 = 6, y2 = 1, color = {0.3, 0.35, 0.45, 0.6}, lineWidth = 1.2},

            -- Vertical structural members
            {x1 = 0, y1 = -8, x2 = 0, y2 = 6, color = {0.8, 0.85, 0.95, 0.5}, lineWidth = 1},
            {x1 = 4, y1 = -4, x2 = 3.5, y2 = 2, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 1},
            {x1 = -4, y1 = -4, x2 = -3.5, y2 = 2, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 1},

            -- Safety markings and identification stripes
            {x1 = -2, y1 = -7, x2 = 2, y2 = -7, color = {1, 0.8, 0.2, 0.8}, lineWidth = 2},
            {x1 = 1, y1 = 4, x2 = 1, y2 = 6, color = {1, 0.8, 0.2, 0.7}, lineWidth = 1.5},
            {x1 = -1, y1 = 4, x2 = -1, y2 = 6, color = {1, 0.8, 0.2, 0.7}, lineWidth = 1.5},
        },

        cockpit = {
            -- Main pilot/sensor dome (larger, more prominent)
            {x = 0, y = -6, r = 2.2, color = {0.3, 0.4, 0.6, 1}},
            -- Sensor highlight ring
            {x = 0, y = -6, r = 1.8, color = {0.9, 0.95, 1, 0.6}},
            -- Internal detail dots (simulating sensor arrays)
            {x = 1, y = -5.5, r = 0.4, color = {0.9, 0.95, 1, 0.9}},
            {x = -1, y = -5.5, r = 0.4, color = {0.9, 0.95, 1, 0.9}},
        },

        -- Main thruster arrays (realistic ion/plasma drives)
        engineGlow = {
            {x = 3, y = 6, r = 1.2, color = {0.6, 0.8, 1, 0.9}},   -- Right main thruster
            {x = -3, y = 6, r = 1.2, color = {0.6, 0.8, 1, 0.9}},  -- Left main thruster
            -- Secondary maneuvering thrusters
            {x = 6, y = 2, r = 0.6, color = {0.7, 0.9, 1, 0.8}},
            {x = -6, y = 2, r = 0.6, color = {0.7, 0.9, 1, 0.8}},
        },

        -- Surface details and utility equipment
        panels = {
            -- Access panel outlines and shadows
            {x1 = -5, y1 = -2, x2 = -2, y2 = -2, color = {0,0,0,0.6}, lineWidth = 1},
            {x1 = 2, y1 = -2, x2 = 5, y2 = -2, color = {0,0,0,0.6}, lineWidth = 1},
            {x1 = -4, y1 = 2, x2 = 4, y2 = 2, color = {0,0,0,0.5}, lineWidth = 1},

            -- Hull plating shadows for depth
            {x = 0, y = 0, r = 6, color = {0,0,0,0.25}}, -- Central shadow
            {x = 4, y = -2, r = 3, color = {0,0,0,0.2}}, -- Right shadow
            {x = -4, y = -2, r = 3, color = {0,0,0,0.2}}, -- Left shadow
        },

        -- Communication and sensor arrays
        sensors = {
            {x = 0, y = -9, r = 0.8, color = {0.9, 0.95, 1, 1}},   -- Main sensor dome
            {x = 2, y = -8, r = 0.5, color = {0.95, 0.95, 1, 0.8}}, -- Navigation sensor
            {x = -2, y = -8, r = 0.5, color = {0.95, 0.95, 1, 0.8}}, -- Communication array
        },

        -- Antenna and utility mounts
        antenna = {
            {x1 = 0, y1 = -9, x2 = 0, y2 = -12, color = {0.95, 0.95, 1, 0.9}, lineWidth = 1.5}, -- Main antenna
            {x1 = 1.5, y1 = -8, x2 = 1.5, y2 = -10, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 1}, -- Secondary antenna
            {x1 = -1.5, y1 = -8, x2 = -1.5, y2 = -10, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 1}, -- Tertiary antenna
        },

        -- Warning and identification markings
        warning = {
            {x1 = -3, y1 = -6, x2 = -1, y2 = -6, color = {1, 0.8, 0.2, 0.9}, lineWidth = 2}, -- Left marking
            {x1 = 1, y1 = -6, x2 = 3, y2 = -6, color = {1, 0.8, 0.2, 0.9}, lineWidth = 2},  -- Right marking
        }
    },
    collisionRadius = 9,

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
