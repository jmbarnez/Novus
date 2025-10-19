---@diagnostic disable: undefined-global
-- Render System - Handles all rendering
-- Manages camera transforms and draws all visual elements

local ECS = require('src.ecs')
local Parallax = require('src.parallax')
local unpack = unpack

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

        if not (canvasComp and cameraComp and cameraPos and color and color[4]) then return end
    
        -- Convert mouse position to world coordinates, accounting for zoom and camera position
    mouseX = (mouseX - canvasComp.offsetX) / canvasComp.scale / cameraComp.zoom + cameraPos.x
    mouseY = (mouseY - canvasComp.offsetY) / canvasComp.scale / cameraComp.zoom + cameraPos.y

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
    if not (polygonShape and color and color[1] and color[2] and color[3] and color[4]) then return end
    if not vertices or #vertices < 3 then return end

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
    -- ...existing code...
    for _, entityId in ipairs(laserEntities) do
        local laser = ECS.getComponent(entityId, "LaserBeam")
        if laser then
            -- ...existing code...
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
                if particle.color and particle.color[1] and particle.color[2] and particle.color[3] and particle.color[4] then
            love.graphics.setColor(
                particle.color[1],
                particle.color[2],
                particle.color[3],
                particle.color[4] * alpha
            )
            love.graphics.circle("fill", particle.x, particle.y, particle.size)
                end
        end
    end
end

local RenderSystem = {
    name = "RenderSystem",

    draw = function()
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        if #canvasEntities == 0 then return end
        local canvasId = canvasEntities[1]
        local canvasComp = ECS.getComponent(canvasId, "Canvas")
        if not canvasComp or not canvasComp.canvas or not canvasComp.width or not canvasComp.height then return end

        love.graphics.setCanvas(canvasComp.canvas)
        love.graphics.clear()

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)

        local starFieldEntities = ECS.getEntitiesWith({"StarField"})
        for _, entityId in ipairs(starFieldEntities) do
            local starFieldComp = ECS.getComponent(entityId, "StarField")
            if starFieldComp then
                local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
                if #cameraEntities > 0 then
                    local cameraId = cameraEntities[1]
                    local cameraPos = ECS.getComponent(cameraId, "Position")
                    if cameraPos then
                        Parallax.draw(starFieldComp, cameraPos.x, cameraPos.y, canvasComp.width, canvasComp.height)
                    end
                end
            end
        end

        local CameraSystem = ECS.getSystem("CameraSystem")
        if CameraSystem and CameraSystem.applyTransform then
            CameraSystem.applyTransform()
        end

        local trailEntities = ECS.getEntitiesWith({"TrailParticle"})
        for _, entityId in ipairs(trailEntities) do
            local particle = ECS.getComponent(entityId, "TrailParticle")
            if particle and particle.life and particle.maxLife and particle.color and particle.x and particle.y and particle.size then
                local alpha = particle.life / particle.maxLife
                love.graphics.setColor(
                    particle.color[1] or 1,
                    particle.color[2] or 1,
                    particle.color[3] or 1,
                    (particle.color[4] or 1) * alpha
                )
                love.graphics.circle("fill", particle.x, particle.y, particle.size)
            end
        end

        drawDebris()

        love.graphics.setCanvas(canvasComp.canvas)
        drawLaser()

        local renderableEntities = ECS.getEntitiesWith({"Position", "Renderable"})
        for _, entityId in ipairs(renderableEntities) do
            local position = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable")
            if not position or not renderable then goto continue_entity end
            local item = ECS.getComponent(entityId, "Item")
            local stack = ECS.getComponent(entityId, "Stack")
            if renderable.shape == "item" and item and item.def and item.def.draw then
                item.def:draw(position.x, position.y)
                if stack and stack.quantity and stack.quantity > 1 then
                    love.graphics.setColor(1, 1, 1, 0.9)
                    local Theme = require('src.ui.theme')
                    local smallFont = Theme.getFont(10)
                    love.graphics.setFont(smallFont)
                    local qtyText = "x" .. tostring(stack.quantity)
                    love.graphics.printf(qtyText, position.x - 40, position.y + 10, 80, "center")
                end
            else
                if renderable.color then
                    love.graphics.setColor(unpack(renderable.color))
                end
                if renderable.shape == "rectangle" and renderable.width and renderable.height then
                    love.graphics.rectangle("fill",
                        position.x - renderable.width/2,
                        position.y - renderable.height/2,
                        renderable.width,
                        renderable.height)
                elseif renderable.shape == "circle" and renderable.radius then
                    love.graphics.circle("fill", position.x, position.y, renderable.radius)
                    -- Draw small health bar for enemies (non-player)
                    if ECS.hasComponent(entityId, "Hull") and not (ECS.hasComponent(entityId, "ControlledBy") and ECS.hasComponent(ECS.getComponent(entityId, "ControlledBy").pilotId, "Player")) then
                        local hull = ECS.getComponent(entityId, "Hull")
                        local shield = ECS.getComponent(entityId, "Shield")
                        if hull then
                            local barWidth = 40
                            local barHeight = 6
                            local x = position.x - barWidth / 2
                            local y = position.y - renderable.radius - 10
                            -- Background
                            love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
                            love.graphics.rectangle("fill", x, y, barWidth, barHeight, 3, 3)
                            -- Fill
                            local ratio = math.max(0, math.min(1, (hull.current or 0) / (hull.max or 1)))
                            -- Draw shield bar (if present) above hull with blue color
                            if shield and shield.max > 0 then
                                local sRatio = math.max(0, math.min(1, (shield.current or 0) / (shield.max or 1)))
                                love.graphics.setColor(0.2, 0.6, 1, 0.9)
                                love.graphics.rectangle("fill", x + 1, y - 8, (barWidth - 2) * sRatio, barHeight - 2, 2, 2)
                            end
                            love.graphics.setColor(1, 0.2, 0.2, 0.95)
                            love.graphics.rectangle("fill", x + 1, y + 1, (barWidth - 2) * ratio, barHeight - 2, 2, 2)
                        end
                    end
                elseif renderable.shape == "polygon" then
                    local polygonShape = ECS.getComponent(entityId, "PolygonShape")
                    if polygonShape then
                        local controlledBy = ECS.getComponent(entityId, "ControlledBy")
                        local isPlayerDrone = false
                        if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player") then
                            isPlayerDrone = true
                        end
                        if isPlayerDrone then
                            local playerRotation = polygonShape.rotation or 0
                            love.graphics.push()
                            love.graphics.translate(position.x, position.y)
                            love.graphics.rotate(playerRotation)
                            drawPolygon(0, 0, polygonShape, renderable.color)
                            love.graphics.pop()
                            drawTurret(position.x, position.y, renderable.color, playerRotation)
                        else
                            drawPolygon(position.x, position.y, polygonShape, renderable.color)
                            -- Draw small health bar for polygon enemies (non-player)
                            if ECS.hasComponent(entityId, "Hull") and not (ECS.hasComponent(entityId, "ControlledBy") and ECS.hasComponent(ECS.getComponent(entityId, "ControlledBy").pilotId, "Player")) then
                                local hull = ECS.getComponent(entityId, "Hull")
                                local shield = ECS.getComponent(entityId, "Shield")
                                if hull then
                                    local barWidth = 48
                                    local barHeight = 6
                                    local x = position.x - barWidth / 2
                                    local y = position.y - 16
                                    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
                                    love.graphics.rectangle("fill", x, y, barWidth, barHeight, 3, 3)
                                    local ratio = math.max(0, math.min(1, (hull.current or 0) / (hull.max or 1)))
                                    if shield and shield.max > 0 then
                                        local sRatio = math.max(0, math.min(1, (shield.current or 0) / (shield.max or 1)))
                                        love.graphics.setColor(0.2, 0.6, 1, 0.9)
                                        love.graphics.rectangle("fill", x + 1, y - 8, (barWidth - 2) * sRatio, barHeight - 2, 2, 2)
                                    end
                                    love.graphics.setColor(1, 0.2, 0.2, 0.95)
                                    love.graphics.rectangle("fill", x + 1, y + 1, (barWidth - 2) * ratio, barHeight - 2, 2, 2)
                                end
                            end
                        end
                    end
                end
            end
            ::continue_entity::
        end

        local mouseX, mouseY = love.mouse.getPosition()
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraId = cameraEntities[1]
            local cameraComp = ECS.getComponent(cameraId, "Camera")
            local cameraPos = ECS.getComponent(cameraId, "Position")
            if cameraComp and cameraPos and canvasComp.offsetX and canvasComp.scale and cameraComp.zoom and cameraPos.x and cameraPos.y then
                mouseX = (mouseX - canvasComp.offsetX) / canvasComp.scale / cameraComp.zoom + cameraPos.x
                mouseY = (mouseY - canvasComp.offsetY) / canvasComp.scale / cameraComp.zoom + cameraPos.y
            end
        end
        local hoveredAsteroidId = nil
        local minDist = math.huge
        local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "PolygonShape", "Durability", "Collidable"})
        for _, id in ipairs(asteroidEntities) do
            local pos = ECS.getComponent(id, "Position")
            local coll = ECS.getComponent(id, "Collidable")
            if pos then
                local radius = coll and coll.radius or 12
                if pos.x and pos.y and mouseX and mouseY then
                    local dx, dy = mouseX - pos.x, mouseY - pos.y
                    local distSq = dx*dx + dy*dy
                    if distSq <= (radius * radius) then
                        if distSq < minDist then
                            minDist = distSq
                            hoveredAsteroidId = id
                        end
                    end
                end
            end
        end
        for _, id in ipairs(asteroidEntities) do
            local pos = ECS.getComponent(id, "Position")
            local coll = ECS.getComponent(id, "Collidable")
            local durability = ECS.getComponent(id, "Durability")
            if pos and durability and durability.current and durability.max then
                local shouldShowBar = (id == hoveredAsteroidId) or (durability.current < durability.max)
                if shouldShowBar then
                    local barW = 24
                    local barH = 3
                    local pad = coll and (coll.radius + 6) or 14
                    local frac = math.max(0, math.min(1, durability.current / durability.max))
                    love.graphics.setColor(0.25, 0.25, 0.2, 0.85)
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW, barH)
                    love.graphics.setColor(1, 1, 0.2, 1)
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW * frac, barH)
                    love.graphics.setColor(0,0,0,1)
                    love.graphics.rectangle("line", pos.x - barW/2, pos.y - pad, barW, barH)
                end
            end
        end
        if CameraSystem and CameraSystem.resetTransform then
            CameraSystem.resetTransform()
        end
        local UISystem = ECS.getSystem("UISystem")
        if UISystem and UISystem.draw then
            UISystem.draw(canvasComp.width, canvasComp.height)
        end
        love.graphics.setColor(1, 1, 0.2, 1)
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 8, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas()
        local w, h = love.graphics.getDimensions()
        local scaleX = w / canvasComp.width
        local scaleY = h / canvasComp.height
        local scale = math.min(scaleX, scaleY)
        local offsetX = (w - canvasComp.width * scale) / 2
        local offsetY = (h - canvasComp.height * scale) / 2
        canvasComp.offsetX = offsetX
        canvasComp.offsetY = offsetY
        canvasComp.scale = scale
        local Scaling = require('src.scaling')
        Scaling.setCanvasTransform(offsetX, offsetY, scale)
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)

        -- Draw HUD overlays in screen space, after canvas is drawn
        local HUDSystem = ECS.getSystem("HUDSystem")
        if HUDSystem and HUDSystem.draw then
            HUDSystem.draw(w, h)
        end
    end
}

return RenderSystem
