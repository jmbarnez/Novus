---@diagnostic disable: undefined-global
-- Render System - Handles all rendering
-- Manages camera transforms and draws all visual elements

local ECS = require('src.ecs')
local Parallax = require('src.parallax')
---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

-- Helper function to check if an entity is on-screen (with padding for safety)
local function isOnScreen(x, y, radius, cameraPos, camera)
    if not (cameraPos and camera) then return true end

    local padding = 100 -- Extra padding to ensure we don't cull too aggressively
    local viewportWidth = camera.width / camera.zoom
    local viewportHeight = camera.height / camera.zoom

    local left = cameraPos.x - padding
    local right = cameraPos.x + viewportWidth + padding
    local top = cameraPos.y - padding
    local bottom = cameraPos.y + viewportHeight + padding

    -- Check if entity's bounding circle intersects viewport
    return x + radius >= left and x - radius <= right and
           y + radius >= top and y - radius <= bottom
end

-- Helper function to draw a turret on top of the drone
-- Draw turret and return muzzle position
local function drawTurret(x, y, color, turretRotation)
    -- Turret barrel length
    local barrelLength = 12
    local barrelOffset = 0 -- If you want to offset the barrel from the center
    -- Draw turret (rectangle pointing right, then rotated)
    love.graphics.setColor(1, 1, 1, color[4])
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(turretRotation)
    love.graphics.rectangle("fill", 0, -2, barrelLength, 4)
    love.graphics.pop()
    -- Calculate muzzle position in world coordinates
    local muzzleX = x + math.cos(turretRotation) * barrelLength
    local muzzleY = y + math.sin(turretRotation) * barrelLength
    return muzzleX, muzzleY
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
            -- Use laser color if available, default to yellow for mining laser
            local color = laser.color or {1, 1, 0, 1}

            -- Draw faint outer beam
            love.graphics.setColor(color[1], color[2], color[3], 0.25) -- Faint colored outer beam
            love.graphics.setLineWidth(4)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)

            -- Draw bright colored core (tinted with laser color, not pure white)
            love.graphics.setColor(color[1], color[2], color[3], 0.9) -- Bright colored core
            love.graphics.setLineWidth(1.5)
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

-- Helper function to draw magnetic field indicator
local function drawMagneticField()
    local ships = ECS.getEntitiesWith({"MagneticField", "Position", "ControlledBy"})
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local position = ECS.getComponent(shipId, "Position")
        if magField and magField.active and position then
            -- Draw a subtle pulsing circle around the ship
            local radius = magField.range
            local time = love.timer.getTime()
            local pulse = 0.3 + 0.2 * math.sin(time * 4)
            love.graphics.setColor(0.4, 0.8, 1, pulse * 0.3)
            love.graphics.circle("line", position.x, position.y, radius)
            love.graphics.setColor(0.6, 0.9, 1, pulse * 0.2)
            love.graphics.circle("line", position.x, position.y, radius * 0.7)
        end
    end
end

local RenderSystem = {
    name = "RenderSystem",

    draw = function()
        local Profiler = require('src.profiler')
        Profiler.start("canvas_setup")

        -- Initialize item rendering counters
        culledItems = 0
        renderedItems = 0

        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        if #canvasEntities == 0 then return end
        local canvasId = canvasEntities[1]
        local canvasComp = ECS.getComponent(canvasId, "Canvas")
        if not canvasComp or not canvasComp.canvas or not canvasComp.width or not canvasComp.height then return end

        love.graphics.setCanvas(canvasComp.canvas)
        love.graphics.clear()

        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, canvasComp.width, canvasComp.height)

        Profiler.stop("canvas_setup")
        Profiler.start("background_draw")

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

        Profiler.stop("background_draw")
        Profiler.start("camera_transform")

        local CameraSystem = ECS.getSystem("CameraSystem")
        if CameraSystem and CameraSystem.applyTransform then
            CameraSystem.applyTransform()
        end

        Profiler.stop("camera_transform")
        Profiler.start("entity_rendering")

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

        -- Get camera for culling calculations
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local cullingCamera = nil
        local cullingCameraPos = nil
        if #cameraEntities > 0 then
            cullingCamera = ECS.getComponent(cameraEntities[1], "Camera")
            cullingCameraPos = ECS.getComponent(cameraEntities[1], "Position")
        end

        local renderableEntities = ECS.getEntitiesWith({"Position", "Renderable"})
        for _, entityId in ipairs(renderableEntities) do
            local position = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable")
            if not position or not renderable then goto continue_entity end
            
            local item = ECS.getComponent(entityId, "Item")
            local stack = ECS.getComponent(entityId, "Stack")
            if renderable.shape == "item" and item and item.def and item.def.draw then
                -- Cull off-screen items
                if not isOnScreen(position.x, position.y, 50, cullingCameraPos, cullingCamera) then
                    culledItems = culledItems + 1
                    goto continue_entity
                end
                renderedItems = renderedItems + 1
                -- All dropped items render at 40% scale (doubled from 20%)
                love.graphics.push()
                love.graphics.translate(position.x, position.y)
                love.graphics.scale(0.4, 0.4)  -- Draw at 40% size
                item.def:draw(0, 0)
                love.graphics.pop()
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
                        -- Cull off-screen asteroids and wreckages
                        local asteroid = ECS.getComponent(entityId, "Asteroid")
                        local wreckage = ECS.getComponent(entityId, "Wreckage")
                        if (asteroid or wreckage) then
                            local collidable = ECS.getComponent(entityId, "Collidable")
                            local radius = collidable and collidable.radius or 20
                            if not isOnScreen(position.x, position.y, radius, cullingCameraPos, cullingCamera) then
                                goto continue_entity
                            end
                        end

                        local controlledBy = ECS.getComponent(entityId, "ControlledBy")
                        local isPlayerDrone = false
                        if controlledBy and controlledBy.pilotId and ECS.hasComponent(controlledBy.pilotId, "Player") then
                            isPlayerDrone = true
                        end
                        local isShip = ECS.hasComponent(entityId, "Hull")
                        if isPlayerDrone then
                            local playerRotation = polygonShape.rotation or 0
                            love.graphics.push()
                            love.graphics.translate(position.x, position.y)
                            love.graphics.rotate(playerRotation)
                            drawPolygon(0, 0, polygonShape, renderable.color)
                            love.graphics.pop()
                            -- Calculate turret aim direction (angle to mouse)
                            local mouseX, mouseY = love.mouse.getPosition()
                            local canvasEntities = ECS.getEntitiesWith({"Canvas"})
                            local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
                            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
                            local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
                            local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
                            if canvasComp and cameraComp and cameraPos then
                                mouseX = (mouseX - canvasComp.offsetX) / canvasComp.scale / cameraComp.zoom + cameraPos.x
                                mouseY = (mouseY - canvasComp.offsetY) / canvasComp.scale / cameraComp.zoom + cameraPos.y
                                local aimAngle = math.atan2(mouseY - position.y, mouseX - position.x)
                                drawTurret(position.x, position.y, renderable.color, aimAngle)
                            else
                                drawTurret(position.x, position.y, renderable.color, playerRotation)
                            end
                        elseif isShip then
                            local enemyRotation = polygonShape.rotation or 0
                            love.graphics.push()
                            love.graphics.translate(position.x, position.y)
                            love.graphics.rotate(enemyRotation)
                            drawPolygon(0, 0, polygonShape, renderable.color)
                            love.graphics.pop()
                            -- Calculate turret aim direction for enemy
                            local turretAimAngle = enemyRotation
                            local turretComp = ECS.getComponent(entityId, "Turret")
                            if turretComp and turretComp.aimX and turretComp.aimY then
                                turretAimAngle = math.atan2(turretComp.aimY - position.y, turretComp.aimX - position.x)
                            end
                            drawTurret(position.x, position.y, renderable.color, turretAimAngle)
                            -- Draw small health bar for polygon enemies (non-player) - only when damaged
                            if ECS.hasComponent(entityId, "Hull") and not (ECS.hasComponent(entityId, "ControlledBy") and ECS.hasComponent(ECS.getComponent(entityId, "ControlledBy").pilotId, "Player")) then
                                local hull = ECS.getComponent(entityId, "Hull")
                                local shield = ECS.getComponent(entityId, "Shield")
                                -- Only show health bar when damaged
                                if hull and (hull.current < hull.max or (shield and shield.current < shield.max)) then
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
                        else
                            drawPolygon(position.x, position.y, polygonShape, renderable.color)
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

        -- Draw shield impact effects
        local ShieldImpactSystem = ECS.getSystem("ShieldImpactSystem")
        if ShieldImpactSystem and ShieldImpactSystem.draw then
            ShieldImpactSystem.draw()
        end

        -- Draw laser beams (rendered on top of ships)
        drawLaser()

        Profiler.stop("entity_rendering")
        Profiler.start("canvas_finalize")



        -- Draw asteroid durability bars (only when damaged)
        local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "Durability", "Collidable"})
        for _, id in ipairs(asteroidEntities) do
            local pos = ECS.getComponent(id, 'Position')
            local coll = ECS.getComponent(id, 'Collidable')
            local durability = ECS.getComponent(id, 'Durability')
            if pos and durability and durability.current and durability.max then
                -- Cull off-screen asteroid health bars
                local radius = coll and coll.radius or 12
                if not isOnScreen(pos.x, pos.y, radius, cullingCameraPos, cullingCamera) then
                    goto continue_asteroid
                end
                
                -- Only show when damaged
                if durability.current < durability.max then
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
            ::continue_asteroid::
        end

        -- Draw wreckage durability bars (green) - only when damaged
        local wreckageEntities = ECS.getEntitiesWith({"Wreckage", "Position", "Durability", "Collidable"})
        for _, id in ipairs(wreckageEntities) do
            local pos = ECS.getComponent(id, 'Position')
            local coll = ECS.getComponent(id, 'Collidable')
            local durability = ECS.getComponent(id, 'Durability')
            if pos and durability and durability.current and durability.max then
                -- Cull off-screen wreckage health bars
                local radius = coll and coll.radius or 12
                if not isOnScreen(pos.x, pos.y, radius, cullingCameraPos, cullingCamera) then
                    goto continue_wreckage
                end
                
                -- Only show when damaged
                if durability.current < durability.max then
                    local barW = 24
                    local barH = 3
                    local pad = coll and (coll.radius + 6) or 14
                    local frac = math.max(0, math.min(1, durability.current / durability.max))
                    love.graphics.setColor(0.15, 0.25, 0.15, 0.85)  -- Dark green background
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW, barH)
                    love.graphics.setColor(0.4, 0.8, 0.4, 1)  -- Muted green fill
                    love.graphics.rectangle("fill", pos.x - barW/2, pos.y - pad, barW * frac, barH)
                    love.graphics.setColor(0,0,0,1)  -- Black outline
                    love.graphics.rectangle("line", pos.x - barW/2, pos.y - pad, barW, barH)
                end
            end
            ::continue_wreckage::
        end

        -- Draw magnetic field indicators
        drawMagneticField()

        -- Draw target indicator around targeted enemy or targeting target
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers > 0 then
            local inputComp = ECS.getComponent(controllers[1], "InputControlled")
            local targetId = inputComp and (inputComp.targetedEnemy or inputComp.targetingTarget)

            if targetId then
                local targetPos = ECS.getComponent(targetId, "Position")
                local targetColl = ECS.getComponent(targetId, "Collidable")

                if targetPos and targetColl then
                    local time = love.timer.getTime()
                    local radius = targetColl.radius + 15

                    if inputComp.targetedEnemy == targetId then
                        -- Locked target - red pulsing circles
                        local pulse = 0.5 + 0.3 * math.sin(time * 4)  -- Pulse between 0.5 and 0.8

                        love.graphics.setColor(1, 0.2, 0.2, pulse)  -- Red with pulsing alpha
                        love.graphics.setLineWidth(3)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                        -- Draw inner circle for more emphasis
                        love.graphics.setColor(1, 0.5, 0.5, pulse * 0.7)
                        love.graphics.setLineWidth(1)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                    elseif inputComp.targetingTarget == targetId then
                        -- Targeting in progress - orange/yellow pulsing circles
                        local pulse = 0.4 + 0.4 * math.sin(time * 8)  -- Faster pulse during targeting

                        love.graphics.setColor(1, 0.8, 0.2, pulse)  -- Orange with pulsing alpha
                        love.graphics.setLineWidth(3)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                        -- Draw inner circle for more emphasis
                        love.graphics.setColor(1, 0.9, 0.5, pulse * 0.7)
                        love.graphics.setLineWidth(1)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                    end
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
        -- FPS counter now handled by HUD System
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas()
        local w, h = love.graphics.getDimensions()
        local scaleX = w / canvasComp.width
        local scaleY = h / canvasComp.height
        local scale = math.min(scaleX, scaleY)
        local offsetX = (w - canvasComp.width * scale) / 2
        local offsetY = (h - canvasComp.height * scale) / 2

        -- Debug canvas scaling (only once per session)
        if not _G.canvasDebugPrinted then
            print(string.format("Canvas: %dx%d, Screen: %dx%d, Scale: %.3f",
                canvasComp.width, canvasComp.height, w, h, scale))
            _G.canvasDebugPrinted = true
        end
        canvasComp.offsetX = offsetX
        canvasComp.offsetY = offsetY
        canvasComp.scale = scale
        local Scaling = require('src.scaling')
        Scaling.setCanvasTransform(offsetX, offsetY, scale)

        -- Profile the actual canvas draw operation
        Profiler.start("canvas_draw")
        love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
        Profiler.stop("canvas_draw")

        Profiler.stop("canvas_finalize")
        Profiler.start("ui_overlay")

        -- Draw HUD overlays in screen space, after canvas is drawn
        local HUDSystem = ECS.getSystem("HUDSystem")
        if HUDSystem and HUDSystem.draw then
            HUDSystem.draw(w, h)
        end

        Profiler.stop("ui_overlay")
    end
}

return RenderSystem
