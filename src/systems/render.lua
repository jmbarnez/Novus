---@diagnostic disable: undefined-global
-- Render System - Handles all rendering
-- Manages camera transforms and draws all visual elements

local ECS = require('src.ecs')
local Parallax = require('src.parallax')

-- Helper function to draw a turret on top of the drone
local function drawTurret(x, y, color, playerRotation)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()

    -- Get canvas and viewport information
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")

    -- Convert mouse position to world coordinates, accounting for zoom and camera position
    mouseX = (mouseX / cameraComp.zoom - canvasComp.offsetX) / canvasComp.scale + cameraPos.x
    mouseY = (mouseY / cameraComp.zoom - canvasComp.offsetY) / canvasComp.scale + cameraPos.y

    -- Calculate angle between drone and mouse relative to the drone's rotation
    local angle = math.atan2(mouseY - y, mouseX - x) - playerRotation

    -- Draw turret (rectangle pointing right, then rotated)
    love.graphics.setColor(1, 1, 1, color[4]) -- White turret barrel
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(playerRotation) -- Rotate with the drone
    love.graphics.rotate(angle) -- Then rotate turret relative to drone
    love.graphics.rectangle("fill", 0, -2, 12, 4) -- 12 pixels long, 4 pixels wide
    love.graphics.pop()
end

-- Helper function to draw a polygon shape
local function drawPolygon(x, y, polygonShape, color)
    local vertices = polygonShape.vertices
    local rotation = polygonShape.rotation
    
    if #vertices < 3 then return end
    
    -- Transform vertices to world coordinates
    local worldVertices = {}
    for i = 1, #vertices do
        local v = vertices[i]
        -- Apply rotation
        local cos = math.cos(rotation)
        local sin = math.sin(rotation)
        local rotatedX = v.x * cos - v.y * sin
        local rotatedY = v.x * sin + v.y * cos
        -- Translate to world position
        table.insert(worldVertices, x + rotatedX)
        table.insert(worldVertices, y + rotatedY)
    end
    
    -- Draw the polygon
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.polygon("fill", worldVertices)
    
    -- Draw outline
    love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, color[4])
    love.graphics.polygon("line", worldVertices)
end

-- Helper function to draw the mining laser
local function drawLaser()
    local laserEntities = ECS.getEntitiesWith({"LaserBeam"})
    if #laserEntities > 0 then
        print("Drawing " .. #laserEntities .. " laser beams")
    end
    for _, entityId in ipairs(laserEntities) do
        local laser = ECS.getComponent(entityId, "LaserBeam")
        if laser then
            print("Laser beam: start=(" .. laser.start.x .. "," .. laser.start.y .. ") end=(" .. laser.endPos.x .. "," .. laser.endPos.y .. ")")
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.setLineWidth(2)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)
            love.graphics.setLineWidth(1)
        end
    end
end

-- Helper function to draw debris particles
local function drawDebris()
    local debrisEntities = ECS.getEntitiesWith({"DebrisParticle"})
    for _, entityId in ipairs(debrisEntities) do
        local particle = ECS.getComponent(entityId, "DebrisParticle")
        if particle then
            -- Calculate alpha based on remaining life
            local alpha = particle.life / particle.maxLife
            love.graphics.setColor(
                particle.color[1],
                particle.color[2],
                particle.color[3],
                particle.color[4] * alpha
            )

            -- Draw particle as a circle that fades over time
            love.graphics.circle("fill", particle.x, particle.y, particle.size)
        end
    end
end

local RenderSystem = {
    name = "RenderSystem",

    draw = function()
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})

        for _, canvasId in ipairs(canvasEntities) do
            local canvasComp = ECS.getComponent(canvasId, "Canvas")

            -- Set canvas as render target
            love.graphics.setCanvas(canvasComp.canvas)
            love.graphics.clear()

            -- Draw black space background
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)

            -- Render starfield BEFORE camera transform (true background)
            local starFieldEntities = ECS.getEntitiesWith({"StarField"})
            for _, entityId in ipairs(starFieldEntities) do
                local starFieldComp = ECS.getComponent(entityId, "StarField")
                if starFieldComp then
                    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
                    if #cameraEntities > 0 then
                        local cameraId = cameraEntities[1]
                        local cameraPos = ECS.getComponent(cameraId, "Position")

                        -- Draw the parallax starfield (starFieldComp is now a parallax object)
                        Parallax.draw(starFieldComp, cameraPos.x, cameraPos.y, canvasComp.width, canvasComp.height)
                    end
                end
            end

            -- Apply camera transform AFTER stars (so stars stay in background)
            local CameraSystem = ECS.getSystem("CameraSystem")
            if CameraSystem and CameraSystem.applyTransform then
                CameraSystem.applyTransform()
            end

            -- Render trail particles (behind ship, in front of stars)
            local trailEntities = ECS.getEntitiesWith({"TrailParticle"})
            for _, entityId in ipairs(trailEntities) do
                local particle = ECS.getComponent(entityId, "TrailParticle")

                -- Calculate alpha based on remaining life
                local alpha = particle.life / particle.maxLife
                love.graphics.setColor(
                    particle.color[1],
                    particle.color[2],
                    particle.color[3],
                    particle.color[4] * alpha
                )

                -- Draw particle as a circle that fades over time
                love.graphics.circle("fill", particle.x, particle.y, particle.size)
            end

            -- Render debris particles
            drawDebris()

            -- Render laser beam
            drawLaser()

            -- Render regular entities
            local renderableEntities = ECS.getEntitiesWith({"Position", "Renderable"})

            for _, entityId in ipairs(renderableEntities) do
                local position = ECS.getComponent(entityId, "Position")
                local renderable = ECS.getComponent(entityId, "Renderable")
                local item = ECS.getComponent(entityId, "Item")

                -- Draw items using their custom draw method
                if renderable.shape == "item" and item and item.def and item.def.draw then
                    item.def:draw(position.x, position.y)
                -- Draw all other entities using their renderable component
                else
                    -- Set color
                    love.graphics.setColor(unpack(renderable.color))

                    -- Draw based on shape
                    if renderable.shape == "rectangle" then
                        love.graphics.rectangle("fill",
                            position.x - renderable.width/2,
                            position.y - renderable.height/2,
                            renderable.width,
                            renderable.height)
                    elseif renderable.shape == "polygon" then
                        local polygonShape = ECS.getComponent(entityId, "PolygonShape")
                        if polygonShape and ECS.hasComponent(entityId, "InputControlled") then
                            -- If it's the player, draw the drone design and turret
                            local playerRotation = polygonShape.rotation
                            love.graphics.push()
                            love.graphics.translate(position.x, position.y)
                            love.graphics.rotate(playerRotation)
                            -- Draw the single Renderable polygon for the player entity
                            drawPolygon(0, 0, polygonShape, renderable.color)
                            love.graphics.pop()
                            drawTurret(position.x, position.y, renderable.color, playerRotation) -- Pass playerRotation to drawTurret
                        elseif polygonShape then
                            -- Otherwise, draw the polygon for asteroids
                            drawPolygon(position.x, position.y, polygonShape, renderable.color)
                        end
                    end
                end
            end

            -- After drawing entities, draw asteroid durability bar on hover or when taking damage
            -- Calculate world mouse position
            local mouseX, mouseY = love.mouse.getPosition()
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            if #cameraEntities > 0 then
                local cameraId = cameraEntities[1]
                local cameraComp = ECS.getComponent(cameraId, "Camera")
                local cameraPos = ECS.getComponent(cameraId, "Position")
                mouseX = (mouseX / cameraComp.zoom - canvasComp.offsetX) / canvasComp.scale + cameraPos.x
                mouseY = (mouseY / cameraComp.zoom - canvasComp.offsetY) / canvasComp.scale + cameraPos.y
            end

            local hoveredAsteroidId = nil
            local minDist = math.huge

            local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "PolygonShape", "Durability", "Collidable"})
            
            -- First pass: find hovered asteroid
            for _, id in ipairs(asteroidEntities) do
                local pos = ECS.getComponent(id, "Position")
                local coll = ECS.getComponent(id, "Collidable")
                local radius = coll and coll.radius or 12
                
                -- Check if hovered
                local dx, dy = mouseX - pos.x, mouseY - pos.y
                local distSq = dx*dx + dy*dy
                if distSq <= (radius * radius) then
                    -- Closest asteroid under pointer
                    if distSq < minDist then
                        minDist = distSq
                        hoveredAsteroidId = id
                    end
                end
            end
            
            -- Second pass: render durability bars (only once per asteroid)
            for _, id in ipairs(asteroidEntities) do
                local pos = ECS.getComponent(id, "Position")
                local coll = ECS.getComponent(id, "Collidable")
                local durability = ECS.getComponent(id, "Durability")
                
                -- Show durability bar if:
                -- 1. Asteroid is hovered
                -- 2. Asteroid is damaged (not at full health)
                local shouldShowBar = (id == hoveredAsteroidId) or (durability.current < durability.max)
                
                if shouldShowBar then
                    -- Bar params
                    local barW = 24
                    local barH = 3
                    local pad = coll and (coll.radius + 6) or 14
                    local frac = math.max(0, math.min(1, durability.current / durability.max))
                    -- Draw BG (gray)
                    love.graphics.setColor(0.25, 0.25, 0.2, 0.85)
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW, barH)
                    -- Draw yellow current bar
                    love.graphics.setColor(1, 1, 0.2, 1)
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW * frac, barH)
                    -- Draw border
                    love.graphics.setColor(0,0,0,1)
                    love.graphics.rectangle("line", pos.x - barW/2, pos.y - pad, barW, barH)
                end
            end

            if CameraSystem and CameraSystem.resetTransform then
                CameraSystem.resetTransform()
            end

            -- Draw UI
            local UISystem = ECS.getSystem("UISystem")
            if UISystem and UISystem.draw then
                UISystem.draw(canvasComp.width, canvasComp.height)
            end

            -- FPS overlay
            love.graphics.setColor(1, 1, 0.2, 1)
            love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 8, 4)
            love.graphics.setColor(1, 1, 1, 1)

            -- Unset canvas and draw to screen
            love.graphics.setCanvas()
            local w, h = love.graphics.getDimensions()
            local scaleX = w / canvasComp.width
            local scaleY = h / canvasComp.height
            local scale = math.min(scaleX, scaleY)
            local offsetX = (w - canvasComp.width * scale) / 2
            local offsetY = (h - canvasComp.height * scale) / 2
            love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
        end
    end
}

return RenderSystem
