-- Component Definitions module
-- Defines all component types used in the ECS
-- Components are pure data structures with no logic

local Components = {}
local Constants = require('src.constants')

-- Position component - 2D coordinates in world space
-- @field x number: X coordinate
-- @field y number: Y coordinate
Components.Position = function(x, y)
    return {
        x = x or 0,
        y = y or 0
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
    }
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
Components.InputControlled = function(controlType, speed)
    return {
        controlType = controlType or "drone",
        speed = speed or 300
    }
end

-- Physics component - Physics properties
-- @field friction number: Air/space resistance (0-1)
-- @field maxSpeed number: Maximum speed limit
-- @field mass number: Mass for physics calculations
Components.Physics = function(friction, maxSpeed, mass)
    return {
        friction = friction or Constants.player_friction,
        maxSpeed = maxSpeed or Constants.player_max_speed,
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
    }
end

-- Tag components - Simple marker components with no data
-- Used for entity categorization and system queries

-- Player tag - Marks the player entity
Components.Player = function()
    return {}
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
    }
end

-- TrailEmitter component - Controls trail particle emission
-- @field emitRate number: Particles per second
-- @field lastEmit number: Time since last emission
-- @field maxParticles number: Maximum particles in trail
-- @field particleLife number: How long particles live
-- @field spreadAngle number: Random spread angle in radians
-- @field speedMultiplier number: How fast particles move relative to ship
Components.TrailEmitter = function(emitRate, maxParticles, particleLife, spreadAngle, speedMultiplier)
    return {
        emitRate = emitRate or Constants.trail_emit_rate, -- particles per second
        lastEmit = 0,
        maxParticles = maxParticles or Constants.trail_max_particles,
        particleLife = particleLife or Constants.trail_particle_life, -- seconds
        spreadAngle = spreadAngle or Constants.trail_spread_angle, -- radians
        speedMultiplier = speedMultiplier or Constants.trail_speed_multiplier
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

-- Health component - Represents the health of an entity
-- @field current number: The current health of the entity
-- @field max number: The maximum health of the entity
Components.Health = function(current, max)
    return {
        current = current or 100,
        max = max or 100
    }
end

-- PolygonShape component - Stores vertex data for irregular polygon rendering and collision
-- @field vertices table: Array of {x, y} points relative to entity position
-- @field rotation number: Current rotation angle in radians
Components.PolygonShape = function(vertices, rotation)
    return {
        vertices = vertices or {},
        rotation = rotation or 0
    }
end

-- AngularVelocity component - Rotation speed
-- @field omega number: Rotation speed in radians per second
Components.AngularVelocity = function(omega)
    return {
        omega = omega or 0
    }
end

-- Asteroid tag component - Marks asteroid entities
Components.Asteroid = function()
    return {}
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

return Components
