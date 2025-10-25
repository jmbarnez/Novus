---@diagnostic disable: undefined-global
-- Wreckage Durability Bars Module
-- Handles durability bars above damaged wreckage

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local WreckageBars = {}

function WreckageBars.draw(viewportWidth, viewportHeight)
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

return WreckageBars
