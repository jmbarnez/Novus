---@diagnostic disable: undefined-global
local Constants = require('src.constants')
local Components = {}

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

-- StarField component - Parallax starfield data
-- @field layers table: Array of layer configurations
-- @field worldSize number: Size of the world for wrapping
Components.StarField = function(layers, worldSize)
    return {
        layers = layers or {},
        worldSize = worldSize or 10000
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

-- LaserBeam component - Represents a laser beam
-- @field start table: The starting position of the laser {x, y}
-- @field endPos table: The ending position of the laser {x, y}
-- @field ownerId number: The entity ID of the owner who fired the laser
Components.LaserBeam = function(data)
    return {
        start = data.start or {x = 0, y = 0},
        endPos = data.endPos or {x = 0, y = 0},
        ownerId = data.ownerId or 0
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
