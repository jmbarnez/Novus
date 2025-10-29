-- World Tooltips System
-- Handles world-space tooltips and interactive elements (different from UI item tooltips)
-- Used for warp gates, world objects, and other entities that need tooltips in world coordinates

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local BatchRenderer = require('src.ui.batch_renderer')
local QuestSystem = require('src.systems.quest_system')

local WorldTooltips = {
    name = "WorldTooltipsSystem",
    priority = 21
}
-- Current render mode: "world" (default) or "hud" (screen/UI layer)
WorldTooltips._renderMode = "hud"

-- Track nearby interactive entities for keyboard input
local nearbyInteractables = {}

-- Track active tooltips and their data
local activeTooltips = {}

-- Track expanded state for tooltips (compact arrows vs full tooltips)
local tooltipExpanded = {}

-- Register a world-space tooltip for an entity
-- @param entityId number: Entity ID
-- @param data table: Tooltip data {title, message, resources?, buttonText?, buttonCallback?}
function WorldTooltips.registerTooltip(entityId, data)
    activeTooltips[entityId] = data
    -- Preserve existing expanded state when re-registering; if there is
    -- no entry yet, start in compact mode by default.
    if tooltipExpanded[entityId] == nil then
        tooltipExpanded[entityId] = false
    end
end

-- Unregister a tooltip
function WorldTooltips.unregisterTooltip(entityId)
    activeTooltips[entityId] = nil
    tooltipExpanded[entityId] = nil
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
        if needsRepair then
            local scrapCount = playerCargo and (playerCargo.items["scrap"] or 0) or 0
            local stoneCount = playerCargo and (playerCargo.items["stone"] or 0) or 0
            local ironCount = playerCargo and (playerCargo.items["iron"] or 0) or 0
            
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

-- NOTE: Tooltips are rendered in HUD/screen space via drawHUD().
-- The old world-space draw function has been removed; proximity checks
-- and rendering are handled inside `drawHUD` so interactions work with
-- the HUD coordinate system.

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
    local interactionRange = 500 -- reduced docking interaction range
        
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
        -- If not interacting with a station, check nearby interactables (warp gates)
        -- Use the nearbyInteractables table populated during draw
        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        local playerCargo = nil
        if #playerEntities > 0 then
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if input and input.targetEntity then
                playerCargo = ECS.getComponent(input.targetEntity, "Cargo")
            end
        end

        for entId, data in pairs(nearbyInteractables) do
            if entId and data and ECS.hasComponent(entId, "WarpGate") then
                local gate = ECS.getComponent(entId, "WarpGate")
                if gate and not gate.active and data.buttonEnabled then
                    -- Required costs (must match update logic)
                    local requiredScrap = 100
                    local requiredStone = 200
                    local requiredIron = 80

                    -- Remove items from cargo (use component methods if present)
                    local removed = true
                    if playerCargo and playerCargo.removeItem then
                        removed = removed and playerCargo:removeItem("scrap", requiredScrap)
                        removed = removed and playerCargo:removeItem("stone", requiredStone)
                        removed = removed and playerCargo:removeItem("iron", requiredIron)
                    else
                        removed = false
                    end

                    if removed then
                        gate.active = true
                        QuestSystem.onWarpGateRepaired(entId)
                        -- Update tooltip immediately
                        WorldTooltips.registerTooltip(entId, {
                            title = "Warp Gate Active",
                            hasResources = false,
                            resources = {},
                            buttonText = nil,
                            buttonEnabled = false,
                            triggerDistance = 800
                        })
                        -- Play repair sound if available
                        local SoundSystem = require('src.systems.sound')
                        if SoundSystem and SoundSystem.play then
                            pcall(function() SoundSystem.play('assets/sounds/repair.ogg') end)
                        end
                    else
                        -- Could show a notification for insufficient resources
                        local Notifications = require('src.ui.notifications')
                        if Notifications and Notifications.show then
                            pcall(function() Notifications.show("Not enough resources to repair the gate") end)
                        end
                    end
                    -- Only handle one interactable per keypress
                    return
                end
            end
        end
    end
end

-- Draw a single tooltip
function WorldTooltips.drawTooltip(entityId, pos, coll, data)
    -- `pos` and `coll` are expected to be in UI/reference (canvas) coordinates
    local gx, gy, gr = pos.x, pos.y, coll.radius or 48

    -- Check if this tooltip is expanded
    local isExpanded = tooltipExpanded[entityId] or false

    if not isExpanded then
        -- Draw compact up arrow button
        WorldTooltips.drawCompactArrow(entityId, gx, gy, gr, data)
    else
        -- Draw full tooltip (original logic)
        WorldTooltips.drawFullTooltip(entityId, gx, gy, gr, data)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw compact up arrow button
function WorldTooltips.drawCompactArrow(entityId, gx, gy, gr, data)
    local arrowSize = 24
    local arrowX = gx
    local arrowY = gy - gr - 8
    local padding = 6
    
    -- Calculate hover state
    local mx, my = love.mouse.getPosition()
    local Scaling = require('src.scaling')
    local renderMode = WorldTooltips._renderMode or "world"
    local isHovered = false
    if renderMode == "hud" then
        local uiMx, uiMy = Scaling.toUI(mx, my)
        isHovered = uiMx and uiMy and uiMx >= arrowX - arrowSize/2 and uiMx <= arrowX + arrowSize/2
                   and uiMy >= arrowY - arrowSize/2 and uiMy <= arrowY + arrowSize/2
    end
    
    -- Background circle
    local bgColor = isHovered and Theme.colors.accent or Theme.colors.surface
    local borderColor = isHovered and Theme.colors.accentHover or Theme.colors.border
    
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 1)
    love.graphics.circle("fill", arrowX, arrowY, arrowSize / 2 + padding)
    
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", arrowX, arrowY, arrowSize / 2 + padding)
    
    -- Draw up arrow
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    love.graphics.setLineWidth(3)
    
    -- Arrow pointing up
    local arrowHeight = arrowSize - 8
    local arrowWidth = arrowSize - 10
    local tipY = arrowY - arrowHeight / 2
    local baseY = arrowY + arrowHeight / 2
    local leftX = arrowX - arrowWidth / 2
    local rightX = arrowX + arrowWidth / 2
    
    love.graphics.line(arrowX, tipY, arrowX, baseY) -- Vertical line
    love.graphics.line(arrowX, tipY, leftX, tipY + 8) -- Left diagonal
    love.graphics.line(arrowX, tipY, rightX, tipY + 8) -- Right diagonal
end

-- Draw full expanded tooltip (original drawTooltip logic)
function WorldTooltips.drawFullTooltip(entityId, gx, gy, gr, data)
    -- Use plasma theme colors
    local font = Theme.getFont(16)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(font)
    local Scaling = require('src.scaling')

    local tw = font:getWidth(data.title)
    local th = font:getHeight()

    -- Compact tooltip dimensions
    local paddingH = 12
    local paddingW = 16
    local minWidth = 180
    local boxW = math.max(tw + paddingW * 2, minWidth)
    local boxH = th + paddingH

    -- Message space
    if data.message then
        love.graphics.setFont(smallFont)
        local msgW = smallFont:getWidth(data.message)
        boxW = math.max(boxW, msgW + paddingW * 2)
        boxH = boxH + smallFont:getHeight() + 6
    end
    
    -- Account for button text width when calculating box width
    if data.buttonText then
        local buttonFont = Theme.getFont(18)
        local buttonTextWidth = buttonFont:getWidth(data.buttonText)
        local minButtonWidth = math.max(160, buttonTextWidth + 24)
        boxW = math.max(boxW, minButtonWidth + paddingW * 2)
    end

    -- Compact resources block
    if data.hasResources then
        -- Account for "Required Resources:" label (height + spacing) + resource list
        boxH = boxH + 18 + 8 + 12 + (#(data.resources or {}) * 16)
    end

    -- Button area (add padding before button to prevent overlap)
    local buttonH = 28
    if data.buttonText then
        -- Add extra padding between content and button
        local buttonPadding = data.hasResources and 4 or 8
        boxH = boxH + buttonPadding + buttonH + 8
    end

    local bx = gx - boxW / 2
    local by = gy - gr - boxH - 8

    -- Draw background and border
    love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 1)
    love.graphics.rectangle("fill", bx, by, boxW, boxH, 0, 0)
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, boxW, boxH, 0, 0)

    -- Minimize button (top-right, looks like Windows minimize)
    do
        local minSize = 16
        local minMargin = 8
        local minX = bx + boxW - minSize - minMargin
        local minY = by + minMargin

        -- Determine hover state in either HUD or world render mode
        local mx, my = love.mouse.getPosition()
        local renderMode = WorldTooltips._renderMode or "world"
        local isHovered = false
        if renderMode == "hud" then
            local uiMx, uiMy = Scaling.toUI(mx, my)
            isHovered = uiMx and uiMy and uiMx >= minX and uiMx <= minX + minSize and uiMy >= minY and uiMy <= minY + minSize
        else
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            if #cameraEntities > 0 then
                local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
                local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
                local wx, wy = Scaling.toWorld(mx, my, cameraComp, cameraPos)
                isHovered = wx and wy and wx >= minX and wx <= minX + minSize and wy >= minY and wy <= minY + minSize
            end
        end

        local btnBg = isHovered and Theme.colors.surfaceAlt or Theme.colors.surface
        local btnBorder = isHovered and Theme.colors.accentHover or Theme.colors.border

        love.graphics.setColor(btnBg[1], btnBg[2], btnBg[3], 1)
        love.graphics.rectangle("fill", minX, minY, minSize, minSize, 0, 0)
        love.graphics.setColor(btnBorder[1], btnBorder[2], btnBorder[3], 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", minX, minY, minSize, minSize, 0, 0)

        -- Draw the minimize underscore
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
        love.graphics.setLineWidth(2)
        local ux1 = minX + 4
        local ux2 = minX + minSize - 4
        local uy = minY + minSize / 2 + 3
        love.graphics.line(ux1, uy, ux2, uy)
    end

    -- Title
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 1)
    love.graphics.print(data.title, bx + (boxW - tw) / 2, by + 8)

    -- Message
    local yOffset = by + th + 12
    if data.message then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
        love.graphics.print(data.message, bx + paddingW, yOffset)
        yOffset = yOffset + smallFont:getHeight() + 6
    end

    -- Resources
    if data.hasResources then
        WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    end

    -- Button (if not drawn inside resources)
    if data.buttonText and not data.hasResources then
        WorldTooltips.drawButton(bx, by, boxW, boxH, data)
    end
    
end

-- Draw tooltips in HUD / screen (UI) space. Converts world positions to UI coordinates
-- and reuses the same tooltip drawing logic but in screen/reference space.
function WorldTooltips.drawHUD()
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then return end

    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    if not cameraComp or not cameraPos then return end

    -- Temporarily set render mode so helpers use UI conversions for hover/click
    local prevMode = WorldTooltips._renderMode
    WorldTooltips._renderMode = "hud"

    for entityId, data in pairs(activeTooltips) do
        local pos = ECS.getComponent(entityId, "Position")
        local coll = ECS.getComponent(entityId, "Collidable")

        if not pos or not coll then
            activeTooltips[entityId] = nil
            goto continue
        end

        -- Check if player is nearby (distance measured in world space)
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
            -- Convert world position to UI/reference coordinates used by HUD
            local gx = (pos.x - cameraPos.x) * (cameraComp and cameraComp.zoom or 1)
            local gy = (pos.y - cameraPos.y) * (cameraComp and cameraComp.zoom or 1)
            local gr = (coll.radius or 80) * (cameraComp and cameraComp.zoom or 1)

            -- Build a lightweight pos/coll table compatible with drawTooltip
            local uiPos = { x = gx, y = gy }
            local uiColl = { radius = gr }

            -- Draw via the existing tooltip painter (now in HUD coords)
            WorldTooltips.drawTooltip(entityId, uiPos, uiColl, data)

            -- Track this as a nearby interactable (used by keyboard input)
            nearbyInteractables[entityId] = data
        else
            nearbyInteractables[entityId] = nil
        end

        ::continue::
    end

    -- Station docking prompt: show a subtle center/HUD prompt when player is within docking range
    -- This is independent of the warp-gate tooltips above.
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local playerPos = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerPos = ECS.getComponent(input.targetEntity, "Position")
        end
    end

    if playerPos then
        local stations = ECS.getEntitiesWith({"Station", "Position", "Collidable"})
        local dockRange = 500
        local nearest = nil
        local ndist = math.huge
        for _, sid in ipairs(stations) do
            local spos = ECS.getComponent(sid, "Position")
            if spos then
                local d = math.sqrt((spos.x - playerPos.x)^2 + (spos.y - playerPos.y)^2)
                if d < dockRange and d < ndist then
                    ndist = d
                    nearest = sid
                end
            end
        end

        if nearest then
            -- Draw subtle prompt in center of screen and a smaller HUD hint near bottom
            local Theme = require('src.ui.theme')
            local Scaling = require('src.scaling')

            local centerX = Scaling.REFERENCE_WIDTH / 2
            local centerY = Scaling.REFERENCE_HEIGHT / 2

            local font = Theme.getFont(20)
            local smallFont = Theme.getFont(14)
            love.graphics.setFont(font)

            -- Use muted text color with slight alpha so it's subtle
            local text = "Press [E/Enter] to dock"
            local tw = font:getWidth(text)
            local th = font:getHeight()

            -- Optional faint background to improve readability
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.rectangle("fill", centerX - tw/2 - 12, centerY - th/2 - 6, tw + 24, th + 12, 6, 6)
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.95)
            love.graphics.print(text, centerX - tw/2, centerY - th/2)

            -- Draw a smaller HUD hint lower on the screen
            love.graphics.setFont(smallFont)
            local hint = "Docking available"
            local hw = smallFont:getWidth(hint)
            local hy = Scaling.REFERENCE_HEIGHT - 120
            -- subtle background for hint
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", centerX - hw/2 - 10, hy - smallFont:getHeight()/2 - 6, hw + 20, smallFont:getHeight() + 12, 6, 6)
            love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], 0.9)
            love.graphics.print(hint, centerX - hw/2, hy - smallFont:getHeight()/2)
        end
    end

    WorldTooltips._renderMode = prevMode or "world"
end

-- Draw resource requirements and button
function WorldTooltips.drawResources(bx, by, th, boxW, boxH, data)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(smallFont)
    local yOffset = by + th + 12

    -- Draw "Required Resources:" label
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    love.graphics.print("Required Resources:", bx + 12, yOffset)
    yOffset = yOffset + 18 + 8

    -- Draw resource list
    if data.resources then
        for i, resource in ipairs(data.resources) do
            local color = resource.hasEnough and {0.1, 0.8, 0.5, 1} or {1, 0.2, 0.5, 1}
            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            love.graphics.print(string.format("%s: %d/%d", resource.name, resource.current, resource.required), bx + 16, yOffset)
            yOffset = yOffset + 16
        end
    end

    -- Draw button if provided
    if data.buttonText then
        local buttonH = 28
        -- Calculate button width to fit text, with min/max constraints
        local buttonFont = Theme.getFont(18)
        love.graphics.setFont(buttonFont)
        local textWidth = buttonFont:getWidth(data.buttonText)
        local buttonW = math.max(160, math.min(textWidth + 24, boxW - 32)) -- Min 160, max boxW-32, add padding
        
        local buttonX = bx + (boxW - buttonW) / 2
        local buttonY = by + boxH - buttonH - 8

        -- Draw using theme button for consistent style and hover
        local mx, my = love.mouse.getPosition()
        local Scaling = require('src.scaling')
        local renderMode = WorldTooltips._renderMode or "world"
        local isHovered = false
        if renderMode == "hud" then
            local uiMx, uiMy = Scaling.toUI(mx, my)
            isHovered = uiMx and uiMy and uiMx >= buttonX and uiMx <= buttonX + buttonW and uiMy >= buttonY and uiMy <= buttonY + buttonH
        else
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            if #cameraEntities > 0 then
                local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
                local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
                local wx, wy = Scaling.toWorld(mx, my, cameraComp, cameraPos)
                isHovered = mx and my and wx >= buttonX and wx <= buttonX + buttonW and wy >= buttonY and wy <= buttonY + buttonH
            end
        end
        -- Use red hover for disabled buttons, green for enabled
        local buttonColor = data.buttonEnabled and Theme.colors.success or Theme.colors.surfaceAlt
        local buttonHoverColor = data.buttonEnabled and Theme.colors.successHover or Theme.colors.dangerHover
        Theme.drawButton(
            buttonX, buttonY, buttonW, buttonH, data.buttonText, isHovered,
            buttonColor,
            buttonHoverColor,
            {textColor = data.buttonEnabled and Theme.colors.text or Theme.colors.textMuted, font = buttonFont}
        )
    end
end

-- Draw button helper function
function WorldTooltips.drawButton(bx, by, boxW, boxH, data)
    local buttonH = 28
    -- Calculate button width to fit text, with min/max constraints
    local buttonFont = Theme.getFont(18)
    love.graphics.setFont(buttonFont)
    local textWidth = buttonFont:getWidth(data.buttonText)
    local buttonW = math.max(160, math.min(textWidth + 24, boxW - 32)) -- Min 160, max boxW-32, add padding
    
    local buttonX = bx + (boxW - buttonW) / 2
    local buttonY = by + boxH - buttonH - 8

    -- Draw using theme button for consistent style and hover
    local mx, my = love.mouse.getPosition()
    local Scaling = require('src.scaling')
    local renderMode = WorldTooltips._renderMode or "world"
    local isHovered = false
    if renderMode == "hud" then
        -- Convert raw screen mouse to UI coordinates (canvas/reference)
        local uiMx, uiMy = Scaling.toUI(mx, my)
        isHovered = uiMx and uiMy and uiMx >= buttonX and uiMx <= buttonX + buttonW and uiMy >= buttonY and uiMy <= buttonY + buttonH
    else
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
            local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
            local wx, wy = Scaling.toWorld(mx, my, cameraComp, cameraPos)
            isHovered = mx and my and wx >= buttonX and wx <= buttonX + buttonW and wy >= buttonY and wy <= buttonY + buttonH
        end
    end
    -- Use red hover for disabled buttons, green for enabled
    local buttonColor = data.buttonEnabled and Theme.colors.success or Theme.colors.surfaceAlt
    local buttonHoverColor = data.buttonEnabled and Theme.colors.successHover or Theme.colors.dangerHover
    Theme.drawButton(
        buttonX, buttonY, buttonW, buttonH, data.buttonText, isHovered,
        buttonColor,
        buttonHoverColor,
        {textColor = data.buttonEnabled and Theme.colors.text or Theme.colors.textMuted, font = buttonFont}
    )
end

-- Handle mouse clicks on world tooltips
function WorldTooltips.handleClick(mx, my, button)
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then return false end

    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    if not cameraComp or not cameraPos then return false end

    local Scaling = require('src.scaling')
    local renderMode = WorldTooltips._renderMode or "world"
    local px, py
    if renderMode == "hud" then
        px, py = Scaling.toUI(mx, my)
    else
        px, py = Scaling.toWorld(mx, my, cameraComp, cameraPos)
    end

    -- Check all nearby interactables for clicks
    for entId, data in pairs(nearbyInteractables) do
        local pos = ECS.getComponent(entId, "Position")
        local coll = ECS.getComponent(entId, "Collidable")
        if pos and coll then
            local renderMode = WorldTooltips._renderMode or "world"
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            local cameraComp = cameraEntities[1] and ECS.getComponent(cameraEntities[1], "Camera")
            local cameraPos = cameraEntities[1] and ECS.getComponent(cameraEntities[1], "Position")

            local gx, gy, gr
            -- If we're in HUD mode, convert world pos to UI/reference coords
            if renderMode == "hud" and cameraComp and cameraPos then
                gx = (pos.x - cameraPos.x) * (cameraComp.zoom or 1)
                gy = (pos.y - cameraPos.y) * (cameraComp.zoom or 1)
                gr = (coll.radius or 48) * (cameraComp.zoom or 1)
            else
                gx, gy, gr = pos.x, pos.y, coll.radius or 48
            end

            local isExpanded = tooltipExpanded[entId] or false

            if not isExpanded then
                -- Check click on compact arrow button
                local arrowSize = 24
                local arrowX = gx
                local arrowY = gy - gr - 8
                local padding = 6
                local arrowRadius = arrowSize / 2 + padding
                
                local distSq = (px - arrowX)^2 + (py - arrowY)^2
                if distSq <= arrowRadius^2 then
                    -- Toggle to expanded state
                    tooltipExpanded[entId] = true
                    return true
                end
            else
                -- Check if click is on full tooltip content (button or inside tooltip area)
                if data.buttonText then
                    -- Check click on button area
                    local font = Theme.getFont(16)
                    local tw = font:getWidth(data.title)
                    local paddingW = 16
                    local minWidth = 180
                    local boxW = math.max(tw + paddingW * 2, minWidth)
                    local boxH = font:getHeight() + 12
                    if data.message then
                        boxH = boxH + Theme.getFont(12):getHeight() + 6
                    end
                    if data.hasResources then
                        -- Account for "Required Resources:" label (height + spacing) + resource list
                        boxH = boxH + 18 + 8 + 12 + (#(data.resources or {}) * 16)
                    end
                    local buttonH = 28
                    if data.buttonText then
                        -- Add extra padding between content and button
                        local buttonPadding = data.hasResources and 4 or 8
                        boxH = boxH + buttonPadding + buttonH + 8
                    end
                    -- Calculate tooltip origin for hit testing
                    local bx = gx - boxW / 2
                    local by = gy - gr - boxH - 8

                    -- Minimize button hit test (top-right)
                    do
                        local minSize = 16
                        local minMargin = 8
                        local minX = bx + boxW - minSize - minMargin
                        local minY = by + minMargin
                        if px >= minX and px <= minX + minSize and py >= minY and py <= minY + minSize then
                            tooltipExpanded[entId] = false
                            return true
                        end
                    end
                    -- Calculate button width for click detection
                    local buttonFont = Theme.getFont(18)
                    local textWidth = buttonFont:getWidth(data.buttonText)
                    local buttonW = math.max(160, math.min(textWidth + 24, boxW - 32))
                    local bx = gx - boxW / 2
                    local by = gy - gr - boxH - 8
                    local buttonX = bx + (boxW - buttonW) / 2
                    local buttonY = by + boxH - buttonH - 8
                    
                    if px >= buttonX and px <= buttonX + buttonW and py >= buttonY and py <= buttonY + buttonH then
                        if data.buttonEnabled then
                            -- Simulate E-key repair logic
                            local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
                            local playerCargo = nil
                            if #playerEntities > 0 then
                                local pilotId = playerEntities[1]
                                local input = ECS.getComponent(pilotId, "InputControlled")
                                if input and input.targetEntity then
                                    playerCargo = ECS.getComponent(input.targetEntity, "Cargo")
                                end
                            end
                            local gate = ECS.getComponent(entId, "WarpGate")
                            if gate and not gate.active then
                                local requiredScrap = 100
                                local requiredStone = 200
                                local requiredIron = 80
                                local removed = true
                                if playerCargo and playerCargo.removeItem then
                                    removed = removed and playerCargo:removeItem("scrap", requiredScrap)
                                    removed = removed and playerCargo:removeItem("stone", requiredStone)
                                    removed = removed and playerCargo:removeItem("iron", requiredIron)
                                else
                                    removed = false
                                end
                                if removed then
                                    gate.active = true
                                    QuestSystem.onWarpGateRepaired(entId)
                                    WorldTooltips.registerTooltip(entId, {
                                        title = "Warp Gate Active",
                                        hasResources = false,
                                        resources = {},
                                        buttonText = nil,
                                        buttonEnabled = false,
                                        triggerDistance = 800
                                    })
                                    local SoundSystem = require('src.systems.sound')
                                    if SoundSystem and SoundSystem.play then
                                        pcall(function() SoundSystem.play('assets/sounds/repair.ogg') end)
                                    end
                                else
                                    local Notifications = require('src.ui.notifications')
                                    if Notifications and Notifications.show then
                                        pcall(function() Notifications.show("Not enough resources to repair the gate") end)
                                    end
                                end
                            end
                        end
                        return true
                    end
                end
                
                -- Check if click is outside tooltip area to collapse it
                local font = Theme.getFont(16)
                local tw = font:getWidth(data.title)
                local paddingW = 16
                local minWidth = 180
                local boxW = math.max(tw + paddingW * 2, minWidth)
                local boxH = font:getHeight() + 12
                if data.message then
                    boxH = boxH + Theme.getFont(12):getHeight() + 6
                end
                if data.hasResources then
                    boxH = boxH + 18 + 8 + 12 + (#(data.resources or {}) * 16)
                end
                local buttonH = 28
                if data.buttonText then
                    local buttonPadding = data.hasResources and 4 or 8
                    boxH = boxH + buttonPadding + buttonH + 8
                end
                local bx = gx - boxW / 2
                local by = gy - gr - boxH - 8
                
                -- If click is outside tooltip bounds, collapse it
                if px < bx or px > bx + boxW or py < by or py > by + boxH then
                    tooltipExpanded[entId] = false
                    return true
                end
            end
        end
    end
    return false
end

return WorldTooltips
