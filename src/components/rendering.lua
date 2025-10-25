---@diagnostic disable: undefined-global
local Constants = require('src.constants')
local Components = {}

-- Renderable component - Visual representation
-- @field shape string: Shape type ("rectangle", "circle", etc.)
-- @field width number: Width for rectangles
-- @field height number: Height for rectangles
-- @field radius number: Radius for circles
-- @field color table: RGBA color {r, g, b, a}
Components.Renderable = function(shape, width, height, radius, color, texture)
    return {
        shape = shape or "rectangle",
        width = width or 10,
        height = height or 10,
        radius = radius or 5,
        color = color or {0, 1, 0, 1}, -- Default green
        texture = texture or nil
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

-- Resize canvas to new dimensions
-- @param canvasComp table: The canvas component to resize
-- @param newWidth number: New width
-- @param newHeight number: New height
function Components.resizeCanvas(canvasComp, newWidth, newHeight)
    if canvasComp and canvasComp.canvas then
        -- Release old canvas
        canvasComp.canvas:release()
        -- Create new canvas with updated dimensions
        canvasComp.canvas = love.graphics.newCanvas(newWidth, newHeight)
        canvasComp.width = newWidth
        canvasComp.height = newHeight
    end
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

-- GalaxyBackdrop component - Distant galaxy rendering data
-- @field size number: Approximate size of the galaxy
-- @field color table: Base color of the galaxy {r, g, b, a}
-- @field spiralTightness number: How tight the spiral arms are
-- @field armCount number: Number of spiral arms
-- @field coreRadius number: Radius of the galaxy core
-- @field armLength number: Length of spiral arms
-- @field armPoints table: Generated spiral arm points
-- @field backgroundStars table: Background stars around galaxy
-- @field nebulaClouds table: Nebula clouds around galaxy
Components.GalaxyBackdrop = function(size, color, spiralTightness, armCount)
    return {
        size = size or 2000,
        color = color or {0.8, 0.6, 1.0, 0.3},
        spiralTightness = spiralTightness or 0.3,
        armCount = armCount or 2,
        coreRadius = (size or 2000) * 0.15,
        armLength = (size or 2000) * 0.8,
        armPoints = {},
        backgroundStars = {},
        nebulaClouds = {}
    }
end

-- NebulaCloud component - Individual nebula cloud rendering
-- @field particles table: Array of particle positions and properties
-- @field color table: Base color {r, g, b, a}
-- @field radius number: Approximate radius of the cloud
-- @field particleCount number: Number of particles in the cloud
-- @field seed number: Random seed for particle generation
Components.NebulaCloud = function(x, y, radius, color, particleCount, seed)
    seed = seed or math.random(1000000)
    math.randomseed(seed)
    
    local particles = {}
    local particleCount = particleCount or 80
    
    -- Generate wispy, organic cloud shapes
    for i = 1, particleCount do
        -- Random angle
        local angle = math.random() * 2 * math.pi
        
        -- Create more organic distribution with multiple density zones
        local distRandom = math.random()
        local dist
        if distRandom < 0.5 then
            -- Core of cloud - dense particles
            dist = math.random() * radius * 0.5
        elseif distRandom < 0.8 then
            -- Middle zone - medium density
            dist = radius * 0.5 + math.random() * radius * 0.4
        else
            -- Outer wisps - sparse particles
            dist = radius * 0.9 + math.random() * radius * 0.6
        end
        
        -- Add organic noise to create wispy tendrils
        local noise1 = math.sin(angle * 2.3) * math.cos(angle * 3.7)
        local noise2 = math.sin(angle * 5.1) * 0.2
        local noiseFactor = (noise1 + noise2) * 0.3
        dist = dist * (1 + noiseFactor)
        
        -- More varied particle sizes - smaller particles for wisps
        local size
        if dist < radius * 0.4 then
            -- Core particles - larger
            size = 3 + math.random() * 5
        elseif dist < radius * 0.7 then
            -- Middle particles - medium
            size = 2 + math.random() * 4
        else
            -- Wisp particles - smaller and more varied
            size = 1 + math.random() * 3
        end
        
        -- Varied brightness based on position
        local brightness
        if dist < radius * 0.3 then
            -- Bright core
            brightness = 0.7 + math.random() * 0.3
        elseif dist < radius * 0.6 then
            -- Medium brightness
            brightness = 0.4 + math.random() * 0.3
        else
            -- Dim wisps
            brightness = 0.2 + math.random() * 0.3
        end
        
        -- Add tendrils extending outward
        local tendrilChance = math.random()
        if tendrilChance > 0.92 then
            -- Create a wispy tendril
            local tendrilAngle = angle + (math.random() - 0.5) * 0.5
            local tendrilLength = radius * 0.8 + math.random() * radius * 0.5
            local tendrilParticles = 3 + math.random() * 5
            for j = 1, tendrilParticles do
                local tendrilDist = dist + j * 15
                table.insert(particles, {
                    x = x + math.cos(tendrilAngle) * tendrilDist,
                    y = y + math.sin(tendrilAngle) * tendrilDist,
                    size = 1 + math.random() * 2,
                    brightness = 0.15 + math.random() * 0.15,
                    alpha = 0.1 + math.random() * 0.2
                })
            end
        end
        
        -- Alpha varies with distance from center
        local alpha
        if dist < radius * 0.4 then
            alpha = 0.5 + math.random() * 0.3
        elseif dist < radius * 0.7 then
            alpha = 0.3 + math.random() * 0.2
        else
            alpha = 0.1 + math.random() * 0.2
        end
        
        table.insert(particles, {
            x = x + math.cos(angle) * dist,
            y = y + math.sin(angle) * dist,
            size = size,
            brightness = brightness,
            alpha = alpha
        })
    end
    
    return {
        particles = particles,
        color = color or {0.5, 0.6, 1.0, 0.5},
        radius = radius or 150,
        particleCount = particleCount,
        seed = seed
    }
end

-- NebulaBackground component - Procedural nebula cloud rendering
-- @field shader love.Shader: Shader for nebula rendering
-- @field intensity number: Intensity of the nebula (0.0-1.0)
-- @field scale number: Scale of the nebula clouds
-- @field speed number: Animation speed
-- @field color1 table: Primary nebula color {r, g, b}
-- @field color2 table: Secondary nebula color {r, g, b}
-- @field color3 table: Accent nebula color {r, g, b}
-- @field parallaxFactor number: Parallax scroll factor (0-1)
Components.NebulaBackground = function(intensity, scale, speed, color1, color2, color3, parallaxFactor)
    return {
        shader = nil, -- Will be initialized by the system
        intensity = intensity or 0.6,
        scale = scale or 0.00008,
        speed = speed or 0.05,
        color1 = color1 or {0.2, 0.3, 0.6},  -- Cool blue
        color2 = color2 or {0.5, 0.2, 0.3},  -- Warm pink
        color3 = color3 or {0.4, 0.15, 0.5},  -- Purple
        parallaxFactor = parallaxFactor or 0.02
    }
end

return Components
