---@diagnostic disable: undefined-global
-- HUD System - Always-on HUD elements (speed, hull/shield)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Tooltips = require('src.ui.tooltips')

local HUDSystem = {
    name = "HUDSystem",
    -- HUD should be drawn inside the canvas (screen-space overlay)
    visible = true, -- HUD is visible by default, force true on load
    hoveredTurretSlot = nil -- Track which turret slot is being hovered
}

local function drawSpeedText(viewportWidth, viewportHeight)
    -- Find pilot entity and their controlled drone
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local velocity = ECS.getComponent(input.targetEntity, "Velocity")
    if not velocity then return end
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)

    -- Position under minimap (top-right, in screen space)
    local minimapSize = 150  -- True pixel size for HUD
    local x = viewportWidth - minimapSize - 20
    local y = 150 + 30

    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(string.format("%.1f u/s", speed), x, y, minimapSize, "center")
end

local function drawHullShieldBar(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local hull = ECS.getComponent(input.targetEntity, "Hull")
    local shield = ECS.getComponent(input.targetEntity, "Shield")
    if not hull then return end

    local barWidth = Scaling.scaleSize(Constants.ui_health_bar_width)
    local barHeight = Scaling.scaleSize(Constants.ui_health_bar_height)
    local x = Scaling.scaleX(20)
    local y = Scaling.scaleY(20)
    local skew = Scaling.scaleSize(15)  -- Skew amount for parallelogram effect

    -- Background parallelogram
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.polygon("fill", 
        x, y, 
        x + barWidth + skew, y, 
        x + barWidth, y + barHeight, 
        x - skew, y + barHeight
    )

    -- Hull fill parallelogram
    local hullRatio = math.min((hull.current or 0) / hull.max, 1.0)
    local fillWidth = barWidth * hullRatio
    love.graphics.setColor(1.0, 0.2, 0.2, 0.9)
    love.graphics.polygon("fill", 
        x, y, 
        x + fillWidth + skew, y, 
        x + fillWidth, y + barHeight, 
        x - skew, y + barHeight
    )

    -- Shield overlay (if present) - draw on top of hull as blue overlay
    if shield and shield.max > 0 then
        local sRatio = math.min((shield.current or 0) / shield.max, 1.0)
        local sFill = barWidth * sRatio
        love.graphics.setColor(0.2, 0.6, 1, 1.0)  -- Solid blue
        love.graphics.polygon("fill", x, y, x + sFill + skew, y, x + sFill, y + barHeight, x - skew, y + barHeight)
    end
end

local function drawTurretSlots(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    
    local droneId = input.targetEntity
    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    if not turretSlots then return end
    
    -- Position slots below the hull bar
    local slotSize = Scaling.scaleSize(48)
    local slotSpacing = Scaling.scaleSize(8)
    local startX = Scaling.scaleX(20)
    local startY = Scaling.scaleY(20) + Scaling.scaleSize(Constants.ui_health_bar_height) + Scaling.scaleY(12)
    
    local ItemDefs = require('src.items.item_loader')
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    -- Reset hover tracking
    HUDSystem.hoveredTurretSlot = nil
    
    -- Draw up to 3 slots
    for slotIndex = 1, 3 do
        local slotX = startX + (slotIndex - 1) * (slotSize + slotSpacing)
        local slotY = startY
        
        -- Check if hovering
        local isHovering = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize
        
        -- Draw slot background
        local bgColor = isHovering and {0.15, 0.15, 0.2, 0.95} or {0.1, 0.1, 0.15, 0.9}
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
        
        -- Draw slot border
        local borderColor = {0.4, 0.4, 0.5, 0.8}
        if turretSlots.slots[slotIndex] then
            borderColor = {0.2, 0.8, 1.0, 1.0} -- Cyan for equipped
        end
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
        love.graphics.setLineWidth(1)
        
        -- Draw equipped module icon or placeholder
        if turretSlots.slots[slotIndex] then
            local itemId = turretSlots.slots[slotIndex]
            local itemDef = ItemDefs[itemId]
            
            if isHovering then
                HUDSystem.hoveredTurretSlot = {
                    itemId = itemId,
                    itemDef = itemDef,
                    mouseX = mx,
                    mouseY = my
                }
            end
            
            if itemDef and itemDef.draw then
                love.graphics.setColor(1, 1, 1, 1)
                itemDef:draw(slotX + slotSize / 2, slotY + slotSize / 2)
            else
                -- Fallback: draw a circle
                love.graphics.setColor(0.5, 0.5, 0.8, 1)
                love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
            end
        else
            -- Empty slot - draw placeholder
            love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
            love.graphics.circle("line", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 4)
        end
    end
end


local Minimap = require('src.systems.minimap')

-- HUDSystem.visible = true -- HUD is visible by default

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

-- Allow draw to be called with or without arguments (fallback to love.graphics.getWidth/Height)
function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080
    drawHullShieldBar(viewportWidth, viewportHeight)
    drawTurretSlots(viewportWidth, viewportHeight)
    -- Draw minimap as part of HUD
    if Minimap and Minimap.draw then
        Minimap.draw()
    end
    drawSpeedText(viewportWidth, viewportHeight)

    -- Draw notifications and experience pop-ups as part of HUD
    local Notifications = require('src.ui.notifications')
    local SkillNotifications = require('src.ui.skill_notifications')
    Notifications.draw(0, 0, 1)
    SkillNotifications.draw()
    
    -- Draw turret slot tooltip if hovering
    if HUDSystem.hoveredTurretSlot and HUDSystem.hoveredTurretSlot.itemDef then
        Tooltips.drawItemTooltip(
            HUDSystem.hoveredTurretSlot.itemId,
            HUDSystem.hoveredTurretSlot.itemDef,
            1,
            HUDSystem.hoveredTurretSlot.mouseX,
            HUDSystem.hoveredTurretSlot.mouseY
        )
    end
end

return HUDSystem
