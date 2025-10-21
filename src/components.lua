---@diagnostic disable: undefined-global
-- Component Definitions module
-- Defines all component types used in the ECS
-- Components are pure data structures with no logic

local Components = {}
local Constants = require('src.constants')

-- Position component - 2D coordinates in world space
-- @field x number: X coordinate
-- @field y number: Y coordinate
-- @field prevX number: Previous X coordinate (for CCD)
-- @field prevY number: Previous Y coordinate (for CCD)
Components.Position = function(x, y)
    return {
        x = x or 0,
        y = y or 0,
        prevX = x or 0,
        prevY = y or 0
    }
end

-- Velocity component - Movement vector
-- @field vx number: X velocity
-- @field vy number: Y velocity
Components.Velocity = function(vx, vy)
    return {
        vx = vx or 0,
        vy = vy or 0
    }
end

-- Acceleration component - Force application
-- @field ax number: X acceleration
-- @field ay number: Y acceleration
Components.Acceleration = function(ax, ay)
    return {
        ax = ax or 0,
        ay = ay or 0
    } -- Close the table definition properly
end

-- Renderable component - Visual representation
-- @field shape string: Shape type ("rectangle", "circle", etc.)
-- @field width number: Width for rectangles
-- @field height number: Height for rectangles
-- @field radius number: Radius for circles
-- @field color table: RGBA color {r, g, b, a}
Components.Renderable = function(shape, width, height, radius, color)
    return {
        shape = shape or "rectangle",
        width = width or 10,
        height = height or 10,
        radius = radius or 5,
        color = color or {0, 1, 0, 1} -- Default green
    }
end

-- InputControlled component - Marks entity as player controllable
-- @field controlType string: Type of control ("drone", "camera", etc.)
-- @field speed number: Movement speed multiplier
-- @field targetedEnemy number: Entity ID of currently targeted enemy (nil if none)
Components.InputControlled = function(controlType, speed)
    return {
        controlType = controlType or "drone",
        speed = speed or Constants.player_max_speed,
        -- targetEntity: optionally references the entity id this controller is piloting
        targetEntity = nil,
        -- targetedEnemy: entity ID of currently targeted enemy ship
        targetedEnemy = nil
    }
end

-- Physics component - Physics properties
-- @field friction number: Air/space resistance (0-1)
-- @field mass number: Mass for physics calculations
Components.Physics = function(friction, mass)
    return {
        friction = friction or Constants.player_friction,
        mass = mass or 1
    }
end

-- CameraTarget component - Marks entity as camera follow target
-- @field priority number: Camera priority (higher = more important)
-- @field smoothing number: Camera smoothing factor (0-1)
Components.CameraTarget = function(priority, smoothing)
    return {
        priority = priority or 1,
        smoothing = smoothing or 0.1
    }
end

-- Boundary component - World boundary constraints
-- @field minX number: Minimum X coordinate
-- @field maxX number: Maximum X coordinate
-- @field minY number: Minimum Y coordinate
-- @field maxY number: Maximum Y coordinate
Components.Boundary = function(minX, maxX, minY, maxY)
    return {
        minX = minX or 0,
        maxX = maxX or 0,
        minY = minY or 0,
        maxY = maxY or 0
    }
end

-- StarField component - Parallax starfield data
-- @field layers table: Array of layer configurations
-- @field worldSize number: Size of the world for wrapping
Components.StarField = function(layers, worldSize)
    return {
        layers = layers or {},
        worldSize = worldSize or 10000
    }
end

-- UI component - User interface data
-- @field uiType string: Type of UI element
-- @field data table: UI-specific data
Components.UI = function(uiType, data)
    return {
        uiType = uiType or "hud",
        data = data or {}
    } -- Close the table definition properly
end

-- Tag components - Simple marker components with no data
-- Used for entity categorization and system queries

-- Player tag - Marks the player entity
Components.Player = function()
    return {}
end

-- ControlledBy component - Marks an entity as being controlled by a pilot
-- @field pilotId number: Entity ID of the pilot controlling this entity
Components.ControlledBy = function(pilotId)
    return {
        pilotId = pilotId or nil
    }
end

-- Camera tag - Marks the camera entity
-- @field width number: The width of the camera viewport
-- @field height number: The height of the camera viewport
-- @field smoothing number: Camera smoothing factor (0-1)
-- @field zoom number: Current zoom level (1.0 = no zoom)
-- @field targetZoom number: The desired zoom level the camera is smoothly approaching
Components.Camera = function(width, height, smoothing, zoom)
    return {
        width = width or 0,
        height = height or 0,
        smoothing = smoothing or 0.1,
        zoom = zoom or 1.0, -- Default zoom level
        targetZoom = zoom or 1.0 -- Initialize targetZoom to current zoom
    }
end

-- TrailParticle component - Individual trail particle data
-- @field x number: Particle X position
-- @field y number: Particle Y position
-- @field vx number: Particle velocity X
-- @field vy number: Particle velocity Y
-- @field life number: Remaining lifetime (0-1)
-- @field maxLife number: Initial lifetime
-- @field size number: Particle size
-- @field color table: Particle color {r, g, b, a}
Components.TrailParticle = function(x, y, vx, vy, life, size, color)
    return {
        x = x or 0,
        y = y or 0,
        vx = vx or 0,
        vy = vy or 0,
        life = life or 1.0,
        maxLife = life or 1.0,
        size = size or 2,
        color = color or {0.5, 0.8, 1.0, 0.8} -- Light blue default
    } -- Close the table definition properly
end

-- TrailEmitter component - Controls trail particle emission
-- @field emitRate number: Particles per second
-- @field lastEmit number: Time since last emission
-- @field maxParticles number: Maximum particles in trail
-- @field particleLife number: How long particles live
-- @field spreadAngle number: Random spread angle in radians
-- @field speedMultiplier number: How fast particles move relative to ship
-- @field trailColor table: Color for trail particles {r, g, b}
Components.TrailEmitter = function(emitRate, maxParticles, particleLife, spreadAngle, speedMultiplier, trailColor)
    return {
        emitRate = emitRate or Constants.trail_emit_rate, -- particles per second
        lastEmit = 0,
        maxParticles = maxParticles or Constants.trail_max_particles,
        particleLife = particleLife or Constants.trail_particle_life, -- seconds
        spreadAngle = spreadAngle or Constants.trail_spread_angle, -- radians
        speedMultiplier = speedMultiplier or Constants.trail_speed_multiplier,
        trailColor = trailColor or {0.3, 0.7, 1.0} -- Default blue-white color (RGB only, alpha handled in trail system)
    } -- Close the table definition properly
end

-- AIController component - Basic AI state for enemies
-- @field state string: Current AI behavior state ("patrol", "chase", "mining", etc.)
-- @field patrolPoints table: Array of waypoints for patrol behavior
-- @field currentPoint number: Index of current patrol point
-- @field speed number: Movement speed for this AI
-- @field detectionRadius number: Radius to detect player
-- @field fireRange number: Maximum range to fire turret
Components.AIController = function(state, patrolPoints, speed, detectionRadius, fireRange)
    return {
        state = state or "patrol",
        patrolPoints = patrolPoints or {},
        currentPoint = 1,
        speed = speed or 80,
        detectionRadius = detectionRadius or 1200,  -- Much larger detection radius (1200 pixels)
        fireRange = fireRange or 2500  -- Fallback fire range, will be overridden by turret specs
    }
end

-- MiningAI component - Marks an entity as a mining AI ship
-- Purely a marker component to identify mining AI ships for ECS queries
Components.MiningAI = function()
    return {
        isMiner = true
    }
end

-- CombatAI component - Marks an entity as a combat AI ship
-- Purely a marker component to identify combat AI ships for ECS queries
Components.CombatAI = function()
    return {
        isCombat = true
    }
end

-- Canvas component - For off-screen rendering
-- @field canvas love.Canvas: The canvas to draw to
-- @field width number: The width of the canvas
-- @field height number: The height of the canvas
-- @field scale number: The scale to draw the canvas at
-- @field offsetX number: The x offset to draw the canvas at
-- @field offsetY number: The y offset to draw the canvas at
Components.Canvas = function(width, height)
    return {
        canvas = love.graphics.newCanvas(width, height),
        width = width,
        height = height,
        scale = 1,
        offsetX = 0,
        offsetY = 0
    }
end

-- UI tag - Marks UI elements
Components.UITag = function()
    return {}
end

-- Hull component - Represents the hull integrity of an entity (hitpoints)
-- @field current number: The current hull value of the entity
-- @field max number: The maximum hull value of the entity
Components.Hull = function(current, max)
    return {
        current = current or 100,
        max = max or 100
    }
end

-- Shield component - Represents shield energy for an entity
-- @field current number: Current shield value
-- @field max number: Maximum shield value
-- @field regen number: Shield regeneration rate (units per second)
-- @field regenDelay number: Seconds to wait after taking damage before regen
-- @field regenTimer number: Internal timer for managing regen delays
Components.Shield = function(current, max, regen, regenDelay)
    return {
        current = current or 0,
        max = max or 0,
        regen = regen or 0,
        regenDelay = regenDelay or 0,
        regenTimer = 0
    }
end

-- PolygonShape component - Stores vertex data for irregular polygon rendering and collision
-- @field vertices table: Array of {x, y} points relative to entity position
-- @field rotation number: Current rotation angle in radians
-- @field prevRotation number: Previous rotation angle (for CCD and rotation change detection)
Components.PolygonShape = function(vertices, rotation)
    return {
        vertices = vertices or {},
        rotation = rotation or 0,
        prevRotation = rotation or 0
    }
end

-- AngularVelocity component - Rotation speed
-- @field omega number: Rotation speed in radians per second
Components.AngularVelocity = function(omega)
    return {
        omega = omega or 0
    }
end

-- Asteroid component - Marks asteroid entities and their type
-- @field asteroidType string: Type of asteroid ("stone" or "iron")
Components.Asteroid = function(asteroidType)
    return {
        asteroidType = asteroidType or "stone"
    }
end

-- Wreckage component - Marks entity as salvageable wreckage from destroyed ships
-- @field sourceShip string: Type or name of the source ship
Components.Wreckage = function(sourceShip)
    return {
        sourceShip = sourceShip or "unknown"
    }
end

-- LootDrop component - Marks whether entity drops loot when destroyed
-- @field dropsScrap boolean: Whether this wreckage drops scrap
-- @field droppedScrap boolean: Whether scrap has already been dropped
Components.LootDrop = function(dropsScrap)
    return {
        dropsScrap = dropsScrap or false,
        droppedScrap = false
    }
end

-- Collidable component - Marks entity for collision detection
-- @field radius number: Bounding circle radius for broad-phase collision
Components.Collidable = function(radius)
    return {
        radius = radius or 10
    }
end

-- Durability component - Represents the health of an entity
-- @field current number: The current durability of the entity
-- @field max number: The maximum durability of the entity
Components.Durability = function(current, max)
    return {
        current = current or 100,
        max = max or 100
    }
end

-- LaserBeam component - Represents a mining laser
-- @field start table: The starting position of the laser {x, y}
-- @field endPos table: The ending position of the laser {x, y}
Components.LaserBeam = function(data)
    return {
        start = data.start or {x = 0, y = 0},
        endPos = data.endPos or {x = 0, y = 0}
    }
end

-- DebrisParticle component - Individual debris particle data
-- @field x number: Particle X position
-- @field y number: Particle Y position
-- @field vx number: Particle velocity X
-- @field vy number: Particle velocity Y
-- @field life number: Remaining lifetime (0-1)
-- @field maxLife number: Initial lifetime
-- @field size number: Particle size
-- @field color table: Particle color {r, g, b, a}
Components.DebrisParticle = function(x, y, vx, vy, life, size, color)
    return {
        x = x or 0,
        y = y or 0,
        vx = vx or 0,
        vy = vy or 0,
        life = life or 1.0,
        maxLife = life or 1.0,
        size = size or 2,
        color = color or {0.8, 0.8, 0.8, 1} -- Light grey default
    }
end

-- Turret component - Manages active turret module and firing state
-- @field moduleName string: The name of the currently equipped turret module
-- @field cooldown number: The cooldown duration in seconds (now read from module)
-- @field lastFireTime number: The time (love.timer.getTime()) when the turret last fired
Components.Turret = function(moduleName)
    return {
        moduleName = moduleName or nil, -- No default, must be set by equipping a module
        lastFireTime = -999, -- Initialize to allow first shot immediately
        heat = 0, -- Current heat for continuous weapons (lasers)
        overheated = false -- Whether the turret is currently overheated
    }
end

-- TurretSlots component - Holds equipped turret modules
-- @field slots table: Array of turret module names/IDs (max 1 for drone)
Components.TurretSlots = function(maxSlots)
    return {
        slots = {},
        maxSlots = maxSlots or 1
    }
end

-- DefensiveSlots component - Holds equipped defensive modules
-- @field slots table: Array of defensive module names/IDs (max 1 for drone)
Components.DefensiveSlots = function(maxSlots)
    return {
        slots = {},
        maxSlots = maxSlots or 1
    }
end

-- Cargo component - Represents inventory or cargo bay for the drone/player
-- @field items table: List or map of items and their amounts
-- @field capacity number: Maximum cargo capacity
Components.Cargo = function(items, capacity)
    return {
        items = items or {},
        capacity = capacity or 10 -- Default 10 slots/items
    }
end

-- MagneticField component - Marks entity as having magnetic collection capability
-- @field active boolean: Whether the magnetic field is currently active
-- @field range number: Collection radius
Components.MagneticField = function(range)
    return {
        active = false,
        range = range or 50
    }
end

-- RotationalMass component - Moment of inertia for rotational physics
-- @field inertia number: Moment of inertia (resistance to rotation)
Components.RotationalMass = function(inertia)
    return {
        inertia = inertia or 1
    }
end

-- Stack component - Tracks quantity of stacked items
-- @field quantity number: How many items in this stack
Components.Stack = function(quantity)
    return {
        quantity = quantity or 1
    }
end

-- Skills component - Tracks player skills and experience
-- @field skills table: Map of skill names to skill data {level, experience, requiredXp}
Components.Skills = function()
    return {
        skills = {
            mining = {
                level = 1,
                experience = 0,
                requiredXp = 100,  -- XP needed for next level
                totalXp = 0        -- Total XP earned (for history)
            },
            salvaging = {
                level = 1,
                experience = 0,
                requiredXp = 100,  -- XP needed for next level
                totalXp = 0        -- Total XP earned (for history)
            }
        }
    }
end

-- Projectile component - Marks an entity as a projectile
-- @field ownerId number: The entity ID of the owner who fired the projectile
-- @field damage number: The amount of damage the projectile deals
-- @field brittle boolean: Whether projectile breaks on impact
-- @field ownerImmunityTime number: Time remaining during which projectile won't collide with owner
Components.Projectile = function(data)
    return {
        ownerId = data.ownerId or 0,
        damage = data.damage or 10,
        brittle = data.brittle or false,
        ownerImmunityTime = data.ownerImmunityTime or 0.2  -- 0.2 seconds of immunity to owner collision
    }
end

-- LastDamager component - Tracks who last damaged an entity
-- @field pilotId number: The pilot ID of whoever dealt the last damage
-- @field weaponType string: The type of weapon used (e.g. "mining_laser", "basic_cannon")
Components.LastDamager = function(pilotId, weaponType)
    return {
        pilotId = pilotId or 0,
        weaponType = weaponType or "unknown"
    }
end

-- ShieldImpact component - Visual effect for shield impacts
-- @field x number: Impact point X position (world space)
-- @field y number: Impact point Y position (world space)
-- @field shipId number: ID of the ship that was hit
-- @field life number: Time remaining for effect
-- @field maxLife number: Total lifetime of effect
Components.ShieldImpact = function(x, y, shipId)
    return {
        x = x or 0,
        y = y or 0,
        shipId = shipId or 0,
        life = 0.6, -- Effect lasts 0.6 seconds
        maxLife = 0.6
    }
end

return Components
