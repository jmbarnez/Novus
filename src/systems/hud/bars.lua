---@diagnostic disable: undefined-global
-- HUD Bars Module - Health bars above enemies, asteroids, and wreckage
-- Uses batched rendering for performance

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDBars = {}

-- Cached font for level indicators (create once, reuse forever)
local levelFont = love.graphics.newFont(8)

function HUDBars.drawEnemyHealthBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not camera or not cameraPos then return end
    
    local shipEntities = ECS.getEntitiesWith({"Hull", "Position", "Renderable"})
    
    -- Extract colors for batching
    local bgColor = PlasmaTheme.colors.healthBarBg
    local hullColor = PlasmaTheme.colors.healthBarFill
    local shieldColor = PlasmaTheme.colors.shieldBarFill
    local outlineColor = PlasmaTheme.colors.outlineBlack
    local outlineWidth = PlasmaTheme.colors.outlineThick
    
    for _, entityId in ipairs(shipEntities) do
        -- Skip player drone
        if ECS.hasComponent(entityId, "ControlledBy") then
            local controlled = ECS.getComponent(entityId, "ControlledBy")
            if controlled and controlled.pilotId and ECS.hasComponent(controlled.pilotId, "Player") then
                goto continue_ship
            end
        end
        
        local position = ECS.getComponent(entityId, "Position")
        local hull = ECS.getComponent(entityId, "Hull")
        local shield = ECS.getComponent(entityId, "Shield")
        local renderable = ECS.getComponent(entityId, "Renderable")
        local level = ECS.getComponent(entityId, "Level")
        
        if position and hull and renderable then
            local canvasX = (position.x - cameraPos.x) * camera.zoom
            local canvasY = (position.y - cameraPos.y) * camera.zoom

            -- Calculate Y offset for health bar (in world units, converted to canvas units via zoom)
            local worldOffsetY = (renderable.radius or 15) + 10  -- world units above entity
            local canvasOffsetY = worldOffsetY * camera.zoom  -- convert to canvas units

            -- Position bars in canvas coordinates (since we're rendering to canvas)
            local barWidth = 32
            local barHeight = 5
            local levelBoxSize = 12
            local levelBoxSpacing = 4  -- Space between level box and health bar

            -- Center the health bar at canvasX, then add level box to the left
            local barX = canvasX - barWidth / 2
            local barY = canvasY - canvasOffsetY
            local levelBoxX = barX - levelBoxSpacing - levelBoxSize
            local levelBoxY = canvasY - canvasOffsetY

            -- Level indicator (always render, default to level 1 if no level component)
            local currentLevel = level and level.level or 1

            -- Red level box background
            BatchRenderer.queueRect(levelBoxX, levelBoxY, levelBoxSize, levelBoxSize, 1, 0, 0, 0.9, 2)

            -- Red level box outline
            BatchRenderer.queueRectLine(levelBoxX, levelBoxY, levelBoxSize, levelBoxSize, 0, 0, 0, 1, 2, 2)

            -- Level number text
            local levelText = tostring(currentLevel)
            local textWidth = levelFont:getWidth(levelText)
            local textHeight = levelFont:getHeight()
            local textX = levelBoxX + (levelBoxSize - textWidth) / 2
            local textY = levelBoxY + (levelBoxSize - textHeight) / 2

            -- White text for contrast against red background
            BatchRenderer.queueText(levelText, textX, textY, levelFont, 1, 1, 1, 1)

            -- Background
            BatchRenderer.queueRect(barX, barY, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 2)

            -- Hull fill with green-to-red gradient based on health
            local hullRatio = math.max(0, math.min(1, (hull.current or 0) / (hull.max or 1)))
            local fillWidth = math.max(0, (barWidth - 2) * hullRatio)
            if fillWidth > 0 then
                -- Green to red gradient: green at 100%, red at 0%
                local r = 1 - hullRatio  -- Red component increases as health decreases
                local g = hullRatio      -- Green component decreases as health decreases
                local b = 0              -- No blue component
                BatchRenderer.queueRect(barX + 1, barY + 1, fillWidth, barHeight - 2, r, g, b, 1, 1)
            end

            -- Shield overlay (if present) - keep cyan color
            if shield and shield.max > 0 then
                local sRatio = math.max(0, math.min(1, (shield.current or 0) / (shield.max or 1)))
                local shieldWidth = math.max(0, (barWidth - 2) * sRatio)
                if shieldWidth > 0 then
                    BatchRenderer.queueRect(barX + 1, barY + 1, shieldWidth, barHeight - 2, shieldColor[1], shieldColor[2], shieldColor[3], shieldColor[4], 1)
                end
            end

            -- Outline
            BatchRenderer.queueRectLine(barX, barY, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], outlineWidth, 2)
        end
        
        ::continue_ship::
    end
end

function HUDBars.drawAsteroidDurabilityBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not camera or not cameraPos then return end
    
    local asteroidEntities = ECS.getEntitiesWith({"Asteroid", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(asteroidEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        -- Only show durability bar if asteroid has taken damage
        if position and durability and durability.current and durability.max and durability.current < durability.max then
            local canvasX = (position.x - cameraPos.x) * camera.zoom
            local canvasY = (position.y - cameraPos.y) * camera.zoom

            -- Calculate Y offset for durability bar (in world units, converted to canvas units via zoom)
            local radius = coll and coll.radius or 12
            local worldOffsetY = radius + 6  -- world units above entity
            local canvasOffsetY = worldOffsetY * camera.zoom  -- convert to canvas units

            -- Position bars in canvas coordinates (since we're rendering to canvas)
            local barWidth = 40
            local barHeight = 4
            local x = canvasX - barWidth / 2
            local y = canvasY - canvasOffsetY

            local frac = math.max(0, math.min(1, durability.current / durability.max))

            -- Draw batched durability bar for asteroid
            local bgColor = PlasmaTheme.colors.healthBarBg
            local fillColor = PlasmaTheme.colors.asteroidBarFill
            local outlineColor = PlasmaTheme.colors.outlineBlack

            BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 1)
            local hasPadding = barHeight > 3
            local fillWidth = math.max(0, (hasPadding and (barWidth - 2) or barWidth) * frac)
            if fillWidth > 0 then
                local fillX = hasPadding and (x + 1) or x
                local fillY = hasPadding and (y + 1) or y
                local fillHeight = hasPadding and (barHeight - 2) or barHeight
                BatchRenderer.queueRect(fillX, fillY, fillWidth, fillHeight, fillColor[1], fillColor[2], fillColor[3], fillColor[4], 0)
            end
            local outlineWidth = hasPadding and 2 or 1
            BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], outlineWidth, 1)
        end
    end
end

function HUDBars.drawWreckageDurabilityBars(viewportWidth, viewportHeight)
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local camera = nil
    local cameraPos = nil
    if #cameraEntities > 0 then
        camera = ECS.getComponent(cameraEntities[1], "Camera")
        cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    end
    
    if not camera or not cameraPos then return end
    
    local wreckageEntities = ECS.getEntitiesWith({"Wreckage", "Position", "Durability", "Collidable"})
    
    for _, entityId in ipairs(wreckageEntities) do
        local position = ECS.getComponent(entityId, "Position")
        local durability = ECS.getComponent(entityId, "Durability")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        -- Only show durability bar if wreckage has taken damage
        if position and durability and durability.current and durability.max and durability.current < durability.max then
            local canvasX = (position.x - cameraPos.x) * camera.zoom
            local canvasY = (position.y - cameraPos.y) * camera.zoom

            -- Calculate Y offset for durability bar (in world units, converted to canvas units via zoom)
            local radius = coll and coll.radius or 12
            local worldOffsetY = radius + 6  -- world units above entity
            local canvasOffsetY = worldOffsetY * camera.zoom  -- convert to canvas units

            -- Position bars in canvas coordinates (since we're rendering to canvas)
            local barWidth = 40
            local barHeight = 4
            local x = canvasX - barWidth / 2
            local y = canvasY - canvasOffsetY

            local frac = math.max(0, math.min(1, durability.current / durability.max))

            -- Draw batched durability bar for wreckage
            local bgColor = PlasmaTheme.colors.healthBarBg
            local fillColor = PlasmaTheme.colors.wreckageBarFill
            local outlineColor = PlasmaTheme.colors.outlineBlack

            BatchRenderer.queueRect(x, y, barWidth, barHeight, bgColor[1], bgColor[2], bgColor[3], bgColor[4], 1)
            local hasPadding = barHeight > 3
            local fillWidth = math.max(0, (hasPadding and (barWidth - 2) or barWidth) * frac)
            if fillWidth > 0 then
                local fillX = hasPadding and (x + 1) or x
                local fillY = hasPadding and (y + 1) or y
                local fillHeight = hasPadding and (barHeight - 2) or barHeight
                BatchRenderer.queueRect(fillX, fillY, fillWidth, fillHeight, fillColor[1], fillColor[2], fillColor[3], fillColor[4], 0)
            end
            local outlineWidth = hasPadding and 2 or 1
            BatchRenderer.queueRectLine(x, y, barWidth, barHeight, outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4], outlineWidth, 1)
        end
    end
end

return HUDBars

