-- Starter Drone Ship Design
-- A realistic small utility drone with practical design elements

return {
    name = "Starter Drone",
    description = "A compact utility drone with modular construction - fast and agile but lightly armored",

    -- Visual design (realistic small spacecraft geometry)
    -- Asymmetric design with sensor pod, main hull, and utility mounts
    polygon = {
        -- Top sensor pod (smaller, offset forward)
        {x = 0,     y = -15},
        -- Upper right hull (angled for aerodynamics in atmosphere transitions)
        {x = 12,    y = -7.5},
        -- Lower right thruster mount
        {x = 13.5,  y = 4.5},
        -- Bottom thruster array
        {x = 0,     y = 12},
        -- Lower left thruster mount
        {x = -13.5, y = 4.5},
        -- Upper left hull
        {x = -12,   y = -7.5},
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
            {x1 = -10.5, y1 = -4.5, x2 = 10.5, y2 = -4.5, color = {0.4, 0.45, 0.55, 0.7}, lineWidth = 2.25},
            {x1 = -9, y1 = 1.5, x2 = 9, y2 = 1.5, color = {0.3, 0.35, 0.45, 0.6}, lineWidth = 1.8},

            -- Vertical structural members
            {x1 = 0, y1 = -12, x2 = 0, y2 = 9, color = {0.8, 0.85, 0.95, 0.5}, lineWidth = 1.5},
            {x1 = 6, y1 = -6, x2 = 5.25, y2 = 3, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 1.5},
            {x1 = -6, y1 = -6, x2 = -5.25, y2 = 3, color = {0.5, 0.55, 0.65, 0.6}, lineWidth = 1.5},

            -- Safety markings and identification stripes
            {x1 = -3, y1 = -10.5, x2 = 3, y2 = -10.5, color = {1, 0.8, 0.2, 0.8}, lineWidth = 3},
            {x1 = 1.5, y1 = 6, x2 = 1.5, y2 = 9, color = {1, 0.8, 0.2, 0.7}, lineWidth = 2.25},
            {x1 = -1.5, y1 = 6, x2 = -1.5, y2 = 9, color = {1, 0.8, 0.2, 0.7}, lineWidth = 2.25},
        },

        cockpit = {
            -- Main pilot/sensor dome (larger, more prominent)
            {x = 0, y = -9, r = 3.3, color = {0.3, 0.4, 0.6, 1}},
            -- Sensor highlight ring
            {x = 0, y = -9, r = 2.7, color = {0.9, 0.95, 1, 0.6}},
            -- Internal detail dots (simulating sensor arrays)
            {x = 1.5, y = -8.25, r = 0.6, color = {0.9, 0.95, 1, 0.9}},
            {x = -1.5, y = -8.25, r = 0.6, color = {0.9, 0.95, 1, 0.9}},
        },

        -- Main thruster arrays (realistic ion/plasma drives)
        engineGlow = {
            {x = 4.5, y = 9, r = 1.8, color = {0.6, 0.8, 1, 0.9}},   -- Right main thruster
            {x = -4.5, y = 9, r = 1.8, color = {0.6, 0.8, 1, 0.9}},  -- Left main thruster
            -- Secondary maneuvering thrusters
            {x = 9, y = 3, r = 0.9, color = {0.7, 0.9, 1, 0.8}},
            {x = -9, y = 3, r = 0.9, color = {0.7, 0.9, 1, 0.8}},
        },

        -- Surface details and utility equipment
        panels = {
            -- Access panel outlines and shadows
            {x1 = -7.5, y1 = -3, x2 = -3, y2 = -3, color = {0,0,0,0.6}, lineWidth = 1.5},
            {x1 = 3, y1 = -3, x2 = 7.5, y2 = -3, color = {0,0,0,0.6}, lineWidth = 1.5},
            {x1 = -6, y1 = 3, x2 = 6, y2 = 3, color = {0,0,0,0.5}, lineWidth = 1.5},

            -- Hull plating shadows for depth
            {x = 0, y = 0, r = 9, color = {0,0,0,0.25}}, -- Central shadow
            {x = 6, y = -3, r = 4.5, color = {0,0,0,0.2}}, -- Right shadow
            {x = -6, y = -3, r = 4.5, color = {0,0,0,0.2}}, -- Left shadow
        },

        -- Communication and sensor arrays
        sensors = {
            {x = 0, y = -13.5, r = 1.2, color = {0.9, 0.95, 1, 1}},   -- Main sensor dome
            {x = 3, y = -12, r = 0.75, color = {0.95, 0.95, 1, 0.8}}, -- Navigation sensor
            {x = -3, y = -12, r = 0.75, color = {0.95, 0.95, 1, 0.8}}, -- Communication array
        },

        -- Antenna and utility mounts
        antenna = {
            {x1 = 0, y1 = -13.5, x2 = 0, y2 = -18, color = {0.95, 0.95, 1, 0.9}, lineWidth = 2.25}, -- Main antenna
            {x1 = 2.25, y1 = -12, x2 = 2.25, y2 = -15, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 1.5}, -- Secondary antenna
            {x1 = -2.25, y1 = -12, x2 = -2.25, y2 = -15, color = {0.9, 0.9, 0.95, 0.7}, lineWidth = 1.5}, -- Tertiary antenna
        },

        -- Warning and identification markings
        warning = {
            {x1 = -4.5, y1 = -9, x2 = -1.5, y2 = -9, color = {1, 0.8, 0.2, 0.9}, lineWidth = 3}, -- Left marking
            {x1 = 1.5, y1 = -9, x2 = 4.5, y2 = -9, color = {1, 0.8, 0.2, 0.9}, lineWidth = 3},  -- Right marking
        }
    },
    collisionRadius = 13.5,
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
