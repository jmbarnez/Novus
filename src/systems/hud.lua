---@diagnostic disable: undefined-global
-- HUD System - Always-on HUD elements (speed, hull/shield)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Tooltips = require('src.ui.tooltips')
local TurretSystem = require('src.systems.turret')

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

local function drawMagneticFieldStatus(viewportWidth, viewportHeight)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    
    local droneId = input.targetEntity
    local magneticField = ECS.getComponent(droneId, "MagneticField")
    if not magneticField then return end
    
    -- Position next to turret slots, under health bar
    local indicatorSize = Scaling.scaleSize(32)
    local startX = Scaling.scaleX(20) + Scaling.scaleSize(48) * 3 + Scaling.scaleSize(8) * 3 + Scaling.scaleSize(16) -- After 3 turret slots
    local startY = Scaling.scaleY(20) + Scaling.scaleSize(Constants.ui_health_bar_height) + Scaling.scaleY(12)
    
    -- Draw indicator background
    local bgColor = magneticField.active and {0.1, 0.3, 0.1, 0.9} or {0.3, 0.1, 0.1, 0.9}
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    love.graphics.rectangle("fill", startX, startY, indicatorSize, indicatorSize, 4, 4)
    
    -- Draw indicator border
    local borderColor = magneticField.active and {0.2, 0.8, 0.2, 1.0} or {0.8, 0.2, 0.2, 1.0}
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", startX, startY, indicatorSize, indicatorSize, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Draw magnetic field icon (M symbol)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    local text = magneticField.active and "M" or "M"
    local textWidth = Theme.getFont(Theme.fonts.small):getWidth(text)
    local textHeight = Theme.getFont(Theme.fonts.small):getHeight()
    love.graphics.printf(text, startX, startY + (indicatorSize - textHeight) / 2, indicatorSize, "center")
    
    -- Draw status text below indicator
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    local statusText = magneticField.active and "ON" or "OFF"
    love.graphics.printf(statusText, startX, startY + indicatorSize + 2, indicatorSize, "center")
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
    local turret = ECS.getComponent(droneId, "Turret")
    local TurretRange = require('src.systems.turret_range')
    
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
        
        -- cooldown overlay handled below (left-to-right); no overlay here

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
            local itemId = turretSlots.slots[slotIndex] -- This is the item ID (e.g., basic_cannon_turret)
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            
            -- Draw equipped turret module icon if available

            if itemDef and itemDef.module and itemDef.module.draw then
                -- If it's a turret, draw from the module
                love.graphics.setColor(1, 1, 1, 1)
                local ok, err = pcall(itemDef.module.draw, itemDef.module, slotX + slotSize / 2, slotY + slotSize / 2)
                if not ok then
                    -- If draw fails, fallback to placeholder icon
                    love.graphics.setColor(0.5, 0.5, 0.8, 1)
                    love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
                end
            elseif itemDef and itemDef.draw then
                -- For non-turret items (if any, though in this slot it's usually turrets), use their itemDef.draw
                love.graphics.setColor(1, 1, 1, 1)
                itemDef:draw(slotX + slotSize / 2, slotY + slotSize / 2)
            else
                -- If no draw function, fallback to placeholder icon
                love.graphics.setColor(0.5, 0.5, 0.8, 1)
                love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
            end
            
            -- For continuous laser weapons, show heat overlay instead of simple cooldown
            if slotIndex == 1 and turret then
                local moduleName = turret.moduleName
                local module = moduleName and TurretSystem.turretModules[moduleName]
                if module and module.CONTINUOUS then
                    -- Overheat overlay: red, fills left-to-right as heat increases
                    local heat = (turret.heat or 0)
                    local maxHeat = module.MAX_HEAT or 10
                    local heatRatio = math.max(0, math.min(heat / maxHeat, 1))
                    -- Draw a subtle inner overlay with padding
                    local pad = math.max(2, math.floor(slotSize * 0.08))
                    local innerH = slotSize - pad * 2
                    local innerW = slotSize - pad * 2
                    local overlayInnerWidth = math.floor(innerW * heatRatio)
                    if turret.overheated then
                        love.graphics.setColor(1.0, 0.2, 0.2, 0.4) -- subtle red
                    else
                        love.graphics.setColor(0.9, 0.3, 0.2, 0.28) -- subtle orange
                    end
                    if overlayInnerWidth > 0 then
                        love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                    end
                elseif module then
                    -- Non-continuous: cooldown overlay - fills left-to-right as cooldown completes
                    local moduleCooldown = TurretRange.getFireCooldown(moduleName)
                    local currentTime = love.timer.getTime()
                    local timeSinceLastFire = currentTime - (turret.lastFireTime or 0)
                    local cooldownRatio = math.max(0, math.min(timeSinceLastFire / moduleCooldown, 1.0))
                    -- Draw subtle inner cooldown overlay
                    local pad = math.max(2, math.floor(slotSize * 0.08))
                    local innerH = slotSize - pad * 2
                    local innerW = slotSize - pad * 2
                    local overlayInnerWidth = math.floor(innerW * cooldownRatio)
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.28) -- subtle green
                    if overlayInnerWidth > 0 then
                        love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                    end
                end
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
    -- drawMagneticFieldStatus(viewportWidth, viewportHeight) -- Removed magnetic field HUD
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
    local slot = HUDSystem.hoveredTurretSlot
    if slot and type(slot) == "table" and slot.itemId and slot.itemDef and slot.mouseX and slot.mouseY then
        Tooltips.drawItemTooltip(
            slot.itemId,
            slot.itemDef,
            1,
            slot.mouseX,
            slot.mouseY
        )
    end
end

return HUDSystem
