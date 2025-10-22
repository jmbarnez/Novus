---@diagnostic disable: undefined-global
-- Render System - Handles all rendering
-- Manages camera transforms and draws all visual elements

local ECS = require('src.ecs')
local Parallax = require('src.parallax')
local ShaderManager = require('src.shader_manager')
local PlasmaTheme = require('src.ui.plasma_theme')
---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

-- Resolve layered colors from a design-like table or fallback to simple color array
local function resolveColors(colorSpec)
    -- Expected layered format: { stripes = {r,g,b,a}, cockpit = {r,g,b,a} }
    -- Fallback: if colorSpec is an array like {r,g,b,a} use it for all layers
    local layers = {
        stripes = {1,1,1,1},
        cockpit = {0.8, 0.8, 0.8, 1}
    }
    if not colorSpec then return layers end
    
    -- If it's a table with numeric indices, treat as simple color
    if colorSpec[1] and type(colorSpec[1]) == 'number' then
        local c = {colorSpec[1] or 1, colorSpec[2] or 1, colorSpec[3] or 1, colorSpec[4] or 1}
        layers.stripes = c
        layers.cockpit = {c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, c[4]}
        return layers
    end

    -- If it's a design color table with stripes/cockpit structure
    if colorSpec.stripes and type(colorSpec.stripes) == 'table' and colorSpec.stripes[1] and type(colorSpec.stripes[1]) == 'number' then
        layers.stripes = colorSpec.stripes
    end
    if colorSpec.cockpit and type(colorSpec.cockpit) == 'table' and colorSpec.cockpit[1] and type(colorSpec.cockpit[1]) == 'number' then
        layers.cockpit = colorSpec.cockpit
    end
    
    -- Also allow shorthand like colorSpec.colors.base
    if colorSpec.colors and type(colorSpec.colors) == 'table' then
        if colorSpec.colors.base and type(colorSpec.colors.base) == 'table' then
            local c = colorSpec.colors.base
            if c[1] and type(c[1]) == 'number' then
                local ctab = {c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1}
                layers.stripes = ctab
                layers.cockpit = colorSpec.colors.cockpit or {ctab[1] * 0.8, ctab[2] * 0.8, ctab[3] * 0.8, ctab[4]}
            end
        end
    end
    return layers
end

-- Helper function to check if an entity is on-screen (with padding for safety)
local function isOnScreen(x, y, radius, cameraPos, camera)
    if not (cameraPos and camera) then return true end

    local padding = 200 -- Extra padding to ensure we don't cull too aggressively
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
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(turretRotation)
    love.graphics.rectangle("fill", 0, -2, barrelLength, 4)
    -- Plasma-style outline for turret
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 0, -2, barrelLength, 4)
    love.graphics.setLineWidth(1)
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
    if not polygonShape or not color then return end
    -- Resolve layered colors
    local colors = resolveColors(color)
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
    -- Draw main hull (stripes)
    love.graphics.setColor(colors.stripes[1], colors.stripes[2], colors.stripes[3], colors.stripes[4])
    love.graphics.polygon("fill", worldVertices)

    -- Draw subtle cockpit highlight (overlay) - only if this polygon has a cockpit defined
    if polygonShape.cockpitRadius then
        local cx = x + (polygonShape.cockpitOffsetX or 0)
        local cy = y + (polygonShape.cockpitOffsetY or 0)
        love.graphics.setColor(colors.cockpit[1], colors.cockpit[2], colors.cockpit[3], (colors.cockpit[4] or 1) * 0.7)
        -- small circle to suggest cockpit
        love.graphics.circle("fill", cx, cy, math.max(3, polygonShape.cockpitRadius))
    end

    -- Draw thick plasma-style outline (multiple passes for thickness)
    love.graphics.setColor(0, 0, 0, colors.stripes[4]) -- Black outline
    love.graphics.setLineWidth(4) -- Thicker outline for stronger Plasma look
    love.graphics.polygon("line", worldVertices)
    
    -- Draw thinner dark outline inside
    love.graphics.setColor(colors.stripes[1] * 0.3, colors.stripes[2] * 0.3, colors.stripes[3] * 0.3, colors.stripes[4])
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", worldVertices)
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end

-- Helper function to draw the mining laser
local function drawLaser()
    local laserEntities = ECS.getEntitiesWith({"LaserBeam"})
    -- ...existing code...
    for _, entityId in ipairs(laserEntities) do
        local laser = ECS.getComponent(entityId, "LaserBeam")
        if laser then
            -- ...existing code...
            -- Use the laser's own color (determined by which laser module it is)
            local color = laser.color or {1, 1, 0, 1}

            -- Draw faint outer beam
            love.graphics.setColor(color[1], color[2], color[3], 0.25) -- Faint colored outer beam
            love.graphics.setLineWidth(4)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)

            -- Draw bright colored core (tinted with laser color, not pure white)
            love.graphics.setColor(color[1], color[2], color[3], 0.9) -- Bright colored core
            love.graphics.setLineWidth(1.5)
            love.graphics.line(laser.start.x, laser.start.y, laser.endPos.x, laser.endPos.y)
            
            -- Plasma-style outline for laser
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.setLineWidth(6)
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

-- Helper function to draw asteroid hotspots
local function drawHotspots()
    local hotspotEntities = ECS.getEntitiesWith({"Hotspot", "Position"})
    for _, hotspotId in ipairs(hotspotEntities) do
        local hotspot = ECS.getComponent(hotspotId, "Hotspot")
        local position = ECS.getComponent(hotspotId, "Position")
        
        if hotspot and position then
            -- Use time since spawn for pulsing animation
            local time = hotspot.timeSinceSpawn
            local pulse = 0.6 + 0.4 * math.sin(time * 3)  -- Pulse faster than magnetic field
            
            -- Calculate opacity based on remaining time (fade out in last 3 seconds)
            local alphaMultiplier = 1.0
            if hotspot.timeRemaining < 3 then
                alphaMultiplier = hotspot.timeRemaining / 3
            end
            
            -- Draw outer pulsing ring - bright orange/red
            love.graphics.setColor(1, 0.5, 0.2, pulse * alphaMultiplier * 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", position.x, position.y, 12)
            
            -- Draw middle ring - orange
            love.graphics.setColor(1, 0.7, 0.3, pulse * alphaMultiplier * 0.6)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", position.x, position.y, 9)
            
            -- Draw inner core - bright white
            love.graphics.setColor(1, 1, 0.8, pulse * alphaMultiplier)
            love.graphics.circle("fill", position.x, position.y, 5)
            
            -- Plasma-style outer glow
            love.graphics.setColor(1, 0.4, 0.1, pulse * alphaMultiplier * 0.5)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", position.x, position.y, 14)
            
            love.graphics.setLineWidth(1)
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

        love.graphics.setColor(0.01, 0.01, 0.015, 1)  -- Very dark blue-black background
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
                -- Quantity text moved out of canvas rendering to avoid shader effects
                -- if stack and stack.quantity and stack.quantity > 1 then
                --     love.graphics.setColor(1, 1, 1, 0.9)
                --     local Theme = require('src.ui.theme')
                --     local smallFont = Theme.getFont(10)
                --     love.graphics.setFont(smallFont)
                --     local qtyText = "x" .. tostring(stack.quantity)
                --     love.graphics.printf(qtyText, position.x - 40, position.y + 10, 80, "center")
                -- end
            else
                if renderable.shape == "rectangle" and renderable.width and renderable.height then
                    if renderable.color then
                        local cols = resolveColors(renderable.color)
                        love.graphics.setColor(cols.stripes[1], cols.stripes[2], cols.stripes[3], cols.stripes[4])
                    end
                    love.graphics.rectangle("fill",
                        position.x - renderable.width/2,
                        position.y - renderable.height/2,
                        renderable.width,
                        renderable.height)
                    
                    -- Draw plasma-style outline for rectangles
                    love.graphics.setColor(0, 0, 0, 1)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line",
                        position.x - renderable.width/2,
                        position.y - renderable.height/2,
                        renderable.width,
                        renderable.height)
                    love.graphics.setLineWidth(1)
                elseif renderable.shape == "circle" and renderable.radius then
                    -- If this entity is a crystal formation, draw shard-like crystals
                    if ECS.hasComponent(entityId, "CrystalFormation") then
                        local cf = ECS.getComponent(entityId, "CrystalFormation")
                        if not cf then goto continue_entity end
                        print(string.format("[Render] Drawing crystal formation %d at (%f, %f)", entityId, position.x, position.y))
                        -- Cull off-screen
                        if not isOnScreen(position.x, position.y, cf.size * 2, cullingCameraPos, cullingCamera) then
                            goto continue_entity
                        end
                        -- Draw multiple shard triangles around center
                        love.graphics.push()
                        love.graphics.translate(position.x, position.y)
                        for i = 1, cf.shardCount do
                            local angle = (i / cf.shardCount) * (2 * math.pi) + (i % 2 == 0 and 0.2 or -0.2)
                            local len = cf.size * (0.6 + math.random() * 0.6)
                            local w = cf.size * 0.35
                            local x1 = 0
                            local y1 = 0
                            local x2 = math.cos(angle) * len
                            local y2 = math.sin(angle) * len
                            -- Perpendicular for base width
                            local bx = math.cos(angle + math.pi/2) * w
                            local by = math.sin(angle + math.pi/2) * w
                            local px1 = x2 + bx
                            local py1 = y2 + by
                            local px2 = x2 - bx
                            local py2 = y2 - by
                            love.graphics.setColor(cf.color[1], cf.color[2], cf.color[3], cf.color[4] or 1)
                            love.graphics.polygon("fill", x1, y1, px1, py1, px2, py2)
                            -- Highlight inner edge
                            love.graphics.setColor(1, 1, 1, 0.6)
                            love.graphics.polygon("fill", 0, 0, x2 * 0.6, y2 * 0.6, x2 * 0.4, y2 * 0.4)
                        end
                        love.graphics.pop()
                    else
                        if renderable.color then
                            local cols = resolveColors(renderable.color)
                            love.graphics.setColor(cols.stripes[1], cols.stripes[2], cols.stripes[3], cols.stripes[4])
                        end
                        love.graphics.circle("fill", position.x, position.y, renderable.radius)
                        
                        -- Draw plasma-style outline for circles
                        love.graphics.setColor(0, 0, 0, 1)
                        love.graphics.setLineWidth(3)
                        love.graphics.circle("line", position.x, position.y, renderable.radius)
                        love.graphics.setLineWidth(1)
                    end
                    -- Draw black border for cannonballs
                    local cannonballBorder = ECS.getComponent(entityId, "CannonballBorder")
                    if cannonballBorder then
                        love.graphics.setColor(cannonballBorder.borderColor)
                        love.graphics.circle("line", position.x, position.y, renderable.radius)
                    end
                    -- Health bars moved to HUD system
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
                                -- Compute turret world position from polygon-local offsets (if present)
                                local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
                                local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
                                local cos = math.cos(playerRotation)
                                local sin = math.sin(playerRotation)
                                local turretWorldX = position.x + (toffX * cos - toffY * sin)
                                local turretWorldY = position.y + (toffX * sin + toffY * cos)
                                drawTurret(turretWorldX, turretWorldY, renderable.color, aimAngle)
                            else
                                local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
                                local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
                                local cos = math.cos(playerRotation)
                                local sin = math.sin(playerRotation)
                                local turretWorldX = position.x + (toffX * cos - toffY * sin)
                                local turretWorldY = position.y + (toffX * sin + toffY * cos)
                                drawTurret(turretWorldX, turretWorldY, renderable.color, playerRotation)
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
                            -- Compute turret world position using polygon-local offsets (if present)
                            local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
                            local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
                            local cosE = math.cos(enemyRotation)
                            local sinE = math.sin(enemyRotation)
                            local turretWorldX = position.x + (toffX * cosE - toffY * sinE)
                            local turretWorldY = position.y + (toffX * sinE + toffY * cosE)
                            drawTurret(turretWorldX, turretWorldY, renderable.color, turretAimAngle)
                        else
                            drawPolygon(position.x, position.y, polygonShape, renderable.color)
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

        -- Draw asteroid hotspots
        drawHotspots()

        Profiler.stop("entity_rendering")
        Profiler.start("canvas_finalize")



        -- Draw magnetic field indicators
        drawMagneticField()

        -- Draw target indicator around targeted enemy or targeting target
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers > 0 then
            local inputComp = ECS.getComponent(controllers[1], "InputControlled")
            local targetId = inputComp and (inputComp.targetedEnemy or inputComp.targetingTarget)

            if inputComp and targetId then
                local targetPos = ECS.getComponent(targetId, "Position")
                local targetColl = ECS.getComponent(targetId, "Collidable")

                if targetPos and targetColl then
                    local time = love.timer.getTime()
                    local radius = targetColl.radius + 15

                    if inputComp.targetedEnemy and inputComp.targetedEnemy == targetId then
                        -- Locked target - red pulsing circles
                        local pulse = 0.5 + 0.3 * math.sin(time * 4)  -- Pulse between 0.5 and 0.8

                        love.graphics.setColor(1, 0.2, 0.2, pulse)  -- Red with pulsing alpha
                        love.graphics.setLineWidth(3)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                        -- Draw inner circle for more emphasis
                        love.graphics.setColor(1, 0.5, 0.5, pulse * 0.7)
                        love.graphics.setLineWidth(1)
                        love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                    elseif inputComp.targetingTarget and inputComp.targetingTarget == targetId then
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
        
        -- Create or reuse post-processing canvas for shader effects
        if not _G.postProcessCanvas or _G.postProcessCanvasWidth ~= w or _G.postProcessCanvasHeight ~= h then
            _G.postProcessCanvas = love.graphics.newCanvas(w, h)
            _G.postProcessCanvasWidth = w
            _G.postProcessCanvasHeight = h
        end
        
        -- Apply shader effect to game canvas and render to post-process canvas
        if ShaderManager.isCelShadingEnabled() then
            ShaderManager.setScreenSize(w, h)
            love.graphics.setShader(ShaderManager.getCelShader())
            love.graphics.setCanvas(_G.postProcessCanvas)
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
            love.graphics.setShader()
            love.graphics.setCanvas()
            -- Draw post-processed result to screen
            love.graphics.draw(_G.postProcessCanvas, 0, 0)
        else
            -- No shader - draw canvas directly to screen
            love.graphics.draw(canvasComp.canvas, offsetX, offsetY, 0, scale, scale)
        end
        
        Profiler.stop("canvas_draw")

        Profiler.stop("canvas_finalize")
        Profiler.start("ui_overlay")

        -- Reset graphics state before drawing UI (ensure no lingering color/blend settings from game canvas)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("alpha")
        
        -- Draw UI windows (notifications, dialogs, windows) - NOT affected by shader
        local UISystem = ECS.getSystem("UISystem")
        if UISystem and UISystem.draw then
            UISystem.draw(canvasComp.width, canvasComp.height)
        end

        -- Draw HUD overlays in screen space, after canvas is drawn
        local HUDSystem = ECS.getSystem("HUDSystem")
        if HUDSystem and HUDSystem.draw then
            HUDSystem.draw(w, h)
        end

        Profiler.stop("ui_overlay")
    end
}

return RenderSystem
