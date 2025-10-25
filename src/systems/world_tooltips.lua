---@diagnostic disable: undefined-global
-- World Tooltips System
-- Handles world-space tooltips and interactive elements (different from UI item tooltips)
-- Used for warp gates, world objects, and other entities that need tooltips in world coordinates

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local BatchRenderer = require('src.ui.batch_renderer')

local WorldTooltips = {
    name = "WorldTooltipsSystem",
    priority = 21
}

-- Track nearby interactive entities for keyboard input
local nearbyInteractables = {}

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
        
        -- Skip stations - they should never show warp gate tooltips
        local station = ECS.getComponent(gateId, "Station")
        if station then goto continue end
        
        -- Only show repair tooltip if explicitly enabled
        if not gate.showRepairTooltip then goto continue end
        
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
            -- Track this as a nearby interactable
            nearbyInteractables[entityId] = data
        else
            -- Remove from nearby if out of range
            nearbyInteractables[entityId] = nil
        end
        
        ::continue::
    end
end

-- Handle keyboard input for nearby interactables
function WorldTooltips.handleKeyPress(key)
    if key == "e" or key == "return" then
        -- Find nearby stations (no tooltip needed, just proximity check)
        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        if #playerEntities == 0 then return end
        
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if not input or not input.targetEntity then return end
        
        local playerPos = ECS.getComponent(input.targetEntity, "Position")
        if not playerPos then return end
        
        -- Check for nearby stations
        local stations = ECS.getEntitiesWith({"Station", "Position", "Collidable"})
        local closestStationId = nil
        local closestDist = math.huge
        local interactionRange = 800
        
        for _, stationId in ipairs(stations) do
            local pos = ECS.getComponent(stationId, "Position")
            if pos then
                local dist = math.sqrt((pos.x - playerPos.x)^2 + (pos.y - playerPos.y)^2)
                if dist < interactionRange and dist < closestDist then
                    closestDist = dist
                    closestStationId = stationId
                end
            end
        end
        
        -- Open quest window if near a station
        if closestStationId then
            local UISystem = require('src.systems.ui')
            local QuestWindow = require('src.ui.quest_window')
            QuestWindow.currentStationId = closestStationId
            UISystem.setQuestWindowOpen(true)
        end
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
    
    -- Add space for message if provided
    if data.message then
        local smallFont = Theme.getFont(12)
        love.graphics.setFont(smallFont)
        local msgW = smallFont:getWidth(data.message)
        boxW = math.max(boxW, msgW + 32)
        boxH = boxH + 16 + 8
    end
    
    -- Add space for content if provided
    if data.hasResources then
        boxH = boxH + 18 + 8 + 48 + 12 + 30 + 8
    end
    
    -- Add space for button if provided
    if data.buttonText then
        boxH = boxH + 30 + 8
    end
    
    local bx = gx - boxW/2
    local by = gy - gr - boxH - 10
    
    -- Draw tooltip background (plasma-style dark background)
    BatchRenderer.queueRect(bx, by, boxW, boxH, Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], 1, 6)
    
    -- Draw thick plasma-style border
    BatchRenderer.queueRectLine(bx, by, boxW, boxH, Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1, 3, 6)
    
    -- Draw title with plasma accent color
    BatchRenderer.queueText(data.title, bx + (boxW - tw) / 2, by + 8, font, Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], 1)
    
    -- Draw message if provided
    local yOffset = by + th + 16
    if data.message then
        local smallFont = Theme.getFont(12)
        BatchRenderer.queueText(data.message, bx + 16, yOffset, smallFont, Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
        yOffset = yOffset + 16 + 8
    end
    
    -- Draw resources if needed
    if data.hasResources then
        WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    end
    
    -- Draw button if provided (and not already drawn via resources)
    if data.buttonText and not data.hasResources then
        WorldTooltips.drawButton(bx, by, boxW, boxH, data)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw resource requirements and button
function WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(smallFont)
    local yOffset = by + th + 16
    
    -- Draw "Required Resources:" label
    BatchRenderer.queueText("Required Resources:", bx + 12, yOffset, smallFont, Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
    yOffset = yOffset + 18 + 8
    
    -- Draw resource list
    if data.resources then
        for i, resource in ipairs(data.resources) do
            local color = resource.hasEnough and {0.1, 0.8, 0.5, 1} or {1, 0.2, 0.5, 1}
            BatchRenderer.queueText(string.format("%s: %d/%d", resource.name, resource.current, resource.required), bx + 16, yOffset, smallFont, color[1], color[2], color[3], 1)
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
        BatchRenderer.queueRect(buttonX, buttonY, buttonW, buttonH, buttonBgColor[1], buttonBgColor[2], buttonBgColor[3], 1, 4)
        
        -- Draw button border
        BatchRenderer.queueRectLine(buttonX, buttonY, buttonW, buttonH, Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1, 2, 4)
        
        -- Draw button text
        local font = Theme.getFont(16)
        local buttonTextW = font:getWidth(data.buttonText)
        BatchRenderer.queueText(data.buttonText, buttonX + (buttonW - buttonTextW) / 2, buttonY + (buttonH - font:getHeight()) / 2, font, buttonTextColor[1], buttonTextColor[2], buttonTextColor[3], 1)
    end
end

-- Draw button helper function
function WorldTooltips.drawButton(bx, by, boxW, boxH, data)
    local buttonW = 200
    local buttonH = 30
    local buttonX = bx + (boxW - buttonW) / 2
    local buttonY = by + boxH - buttonH - 8
    
    local buttonBgColor = data.buttonEnabled and Theme.colors.buttonYes or Theme.colors.bgMedium
    local buttonTextColor = data.buttonEnabled and Theme.colors.textPrimary or Theme.colors.textMuted
    
    -- Draw button background
    BatchRenderer.queueRect(buttonX, buttonY, buttonW, buttonH, buttonBgColor[1], buttonBgColor[2], buttonBgColor[3], 1, 4)
    
    -- Draw button border
    BatchRenderer.queueRectLine(buttonX, buttonY, buttonW, buttonH, Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1, 2, 4)
    
    -- Draw button text
    local font = Theme.getFont(16)
    local buttonTextW = font:getWidth(data.buttonText)
    BatchRenderer.queueText(data.buttonText, buttonX + (buttonW - buttonTextW) / 2, buttonY + (buttonH - font:getHeight()) / 2, font, buttonTextColor[1], buttonTextColor[2], buttonTextColor[3], 1)
end

-- Handle mouse clicks on world tooltips
function WorldTooltips.handleClick(mx, my, button)
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then return false end
    
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    
    if not cameraComp or not cameraPos then return false end
    
    return false
end

return WorldTooltips

