---@diagnostic disable: undefined-global
-- World Tooltips System
-- Handles world-space tooltips and interactive elements (different from UI item tooltips)
-- Used for warp gates, world objects, and other entities that need tooltips in world coordinates

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local WorldTooltips = {
    name = "WorldTooltipsSystem",
    priority = 21
}

-- Track active tooltips and their data
local activeTooltips = {}

-- Register a world-space tooltip for an entity
-- @param entityId number: Entity ID
-- @param data table: Tooltip data {title, message, resources?, buttonText?, buttonCallback?}
function WorldTooltips.registerTooltip(entityId, data)
    activeTooltips[entityId] = data
end

-- Unregister a tooltip
function WorldTooltips.unregisterTooltip(entityId)
    activeTooltips[entityId] = nil
end

-- Update system - registers warp gate tooltips
function WorldTooltips.update(dt)
    -- Register tooltips for all warp gates
    local gateEntities = ECS.getEntitiesWith({"WarpGate", "Position", "Collidable"})
    for _, gateId in ipairs(gateEntities) do
        local gate = ECS.getComponent(gateId, "WarpGate")
        local pos = ECS.getComponent(gateId, "Position")
        local coll = ECS.getComponent(gateId, "Collidable")
        
        if not gate or not pos or not coll then goto continue end
        
        -- Get player cargo to check resources
        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        local playerCargo = nil
        if #playerEntities > 0 then
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if input and input.targetEntity then
                playerCargo = ECS.getComponent(input.targetEntity, "Cargo")
            end
        end
        
        local needsRepair = not gate.active
        local title = needsRepair and "Warp Gate Offline" or "Warp Gate Active"
        
        -- Required resources for repair
        local requiredScrap = 100
        local requiredStone = 200
        local requiredIron = 80
        
        -- Check if player has enough resources
        local hasResources = false
        local resources = {}
        if playerCargo and needsRepair then
            local scrapCount = playerCargo.items["scrap"] or 0
            local stoneCount = playerCargo.items["stone"] or 0
            local ironCount = playerCargo.items["iron"] or 0
            
            hasResources = scrapCount >= requiredScrap and stoneCount >= requiredStone and ironCount >= requiredIron
            
            table.insert(resources, {name = "Scrap", current = scrapCount, required = requiredScrap, hasEnough = scrapCount >= requiredScrap})
            table.insert(resources, {name = "Stone", current = stoneCount, required = requiredStone, hasEnough = stoneCount >= requiredStone})
            table.insert(resources, {name = "Iron", current = ironCount, required = requiredIron, hasEnough = ironCount >= requiredIron})
        end
        
        -- Register tooltip
        WorldTooltips.registerTooltip(gateId, {
            title = title,
            hasResources = needsRepair,
            resources = resources,
            buttonText = hasResources and "Repair Gate" or "Insufficient Resources",
            buttonEnabled = hasResources,
            triggerDistance = 800
        })
        
        ::continue::
    end
end

-- Draw all active world tooltips
function WorldTooltips.draw()
    for entityId, data in pairs(activeTooltips) do
        local pos = ECS.getComponent(entityId, "Position")
        local coll = ECS.getComponent(entityId, "Collidable")
        
        if not pos or not coll then
            activeTooltips[entityId] = nil
            goto continue
        end
        
        -- Check if player is nearby
        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        local playerPos = nil
        if #playerEntities > 0 then
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if input and input.targetEntity then
                playerPos = ECS.getComponent(input.targetEntity, "Position")
            end
        end
        
        if not playerPos then goto continue end
        
        local dist = math.sqrt((pos.x - playerPos.x)^2 + (pos.y - playerPos.y)^2)
        local triggerDistance = data.triggerDistance or 800
        
        if dist < triggerDistance then
            WorldTooltips.drawTooltip(entityId, pos, coll, data)
        end
        
        ::continue::
    end
end

-- Draw a single tooltip
function WorldTooltips.drawTooltip(entityId, pos, coll, data)
    local gx, gy, gr = pos.x, pos.y, coll.radius or 80
    
    -- Use plasma theme colors
    local font = Theme.getFont(16)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(font)
    
    local tw = font:getWidth(data.title)
    local th = font:getHeight()
    
    -- Calculate tooltip dimensions
    local boxW = math.max(tw + 32, 260)
    local boxH = th + 16
    
    -- Add space for content if provided
    if data.hasResources then
        boxH = boxH + 18 + 8 + 48 + 12 + 30 + 8
    end
    
    local bx = gx - boxW/2
    local by = gy - gr - boxH - 10
    
    -- Draw tooltip background (plasma-style dark background)
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", bx, by, boxW, boxH, 6, 6)
    
    -- Draw thick plasma-style border
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", bx, by, boxW, boxH, 6, 6)
    love.graphics.setLineWidth(1)
    
    -- Draw title with plasma accent color
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.setFont(font)
    love.graphics.print(data.title, bx + (boxW - tw) / 2, by + 8)
    
    -- Draw resources and button if needed
    if data.hasResources then
        WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw resource requirements and button
function WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(smallFont)
    local yOffset = by + th + 16
    
    -- Draw "Required Resources:" label
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Required Resources:", bx + 12, yOffset)
    yOffset = yOffset + 18 + 8
    
    -- Draw resource list
    if data.resources then
        for i, resource in ipairs(data.resources) do
            local color = resource.hasEnough and {0.1, 0.8, 0.5, 1} or {1, 0.2, 0.5, 1}
            love.graphics.setColor(color)
            love.graphics.print(string.format("%s: %d/%d", resource.name, resource.current, resource.required), bx + 16, yOffset)
            yOffset = yOffset + 16
        end
    end
    
    -- Draw button if provided
    if data.buttonText then
        local buttonW = 200
        local buttonH = 30
        local buttonX = bx + (boxW - buttonW) / 2
        local buttonY = by + boxH - buttonH - 8
        
        local buttonBgColor = data.buttonEnabled and Theme.colors.buttonYes or Theme.colors.bgMedium
        local buttonTextColor = data.buttonEnabled and Theme.colors.textPrimary or Theme.colors.textMuted
        
        -- Draw button background
        love.graphics.setColor(buttonBgColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 4, 4)
        
        -- Draw button border
        love.graphics.setColor(Theme.colors.borderDark)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Draw button text
        love.graphics.setColor(buttonTextColor)
        local font = Theme.getFont(16)
        love.graphics.setFont(font)
        local buttonTextW = font:getWidth(data.buttonText)
        love.graphics.print(data.buttonText, buttonX + (buttonW - buttonTextW) / 2, buttonY + (buttonH - font:getHeight()) / 2)
    end
end

-- Handle mouse clicks on world tooltips
function WorldTooltips.handleClick(mx, my, button)
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then return false end
    
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    
    if not cameraComp or not cameraPos then return false end
    
    -- TODO: Convert mx, my to world coordinates
    -- TODO: Check if click is within button bounds
    -- TODO: Call button callback if clicked
    
    return false
end

return WorldTooltips

