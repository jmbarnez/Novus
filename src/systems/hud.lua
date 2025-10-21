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

local function drawTargetingIndicator(viewportWidth, viewportHeight)
    -- Find player controller and check for targeted enemy
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input then return end

    local hasTarget = input.targetedEnemy ~= nil
    local isTargeting = input.targetingTarget ~= nil

    -- Position in top-center of screen
    local centerX = viewportWidth / 2
    local y = 20

    if hasTarget then
        -- Get target information for display
        local targetPos = ECS.getComponent(input.targetedEnemy, "Position")
        local targetHull = ECS.getComponent(input.targetedEnemy, "Hull")

        -- Draw targeting reticle/bracket
        love.graphics.setColor(1, 0.2, 0.2, 0.8)  -- Red targeting color
        love.graphics.setLineWidth(2)

        local reticleSize = 15
        -- Draw corner brackets
        love.graphics.line(centerX - reticleSize, y, centerX - reticleSize/2, y)
        love.graphics.line(centerX - reticleSize, y, centerX - reticleSize, y + reticleSize/2)
        love.graphics.line(centerX + reticleSize, y, centerX + reticleSize/2, y)
        love.graphics.line(centerX + reticleSize, y, centerX + reticleSize, y + reticleSize/2)

        -- Draw pulsing center dot
        local time = love.timer.getTime()
        local pulse = 0.3 + 0.4 * math.sin(time * 6)
        love.graphics.setColor(1, 0.2, 0.2, pulse)
        love.graphics.circle("fill", centerX, y + reticleSize/2, 3)

        -- Draw "TARGET LOCKED" text below
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        local text = "TARGET LOCKED"
        local textWidth = Theme.getFont(Theme.fonts.small):getWidth(text)
        love.graphics.printf(text, centerX - textWidth/2, y + reticleSize + 5, textWidth, "left")

        -- Show comprehensive target stats
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))

        local statY = y + reticleSize + 25
        local lineHeight = 15

        -- Enemy type
        local enemyType = "Unknown"
        if ECS.hasComponent(input.targetedEnemy, "CombatAI") then
            enemyType = "Combat"
        elseif ECS.hasComponent(input.targetedEnemy, "MiningAI") then
            enemyType = "Mining"
        elseif ECS.hasComponent(input.targetedEnemy, "MagneticField") then
            enemyType = "Collector"
        end

        local typeText = string.format("TYPE: %s", enemyType)
        local typeWidth = Theme.getFont(Theme.fonts.tiny):getWidth(typeText)
        love.graphics.printf(typeText, centerX - typeWidth/2, statY, typeWidth, "left")
        statY = statY + lineHeight

        -- Distance
        if targetPos then
            local playerPos = ECS.getComponent(input.targetEntity, "Position")
            if playerPos then
                local dx = targetPos.x - playerPos.x
                local dy = targetPos.y - playerPos.y
                local distance = math.sqrt(dx * dx + dy * dy)

                local distText = string.format("DIST: %.0f u", distance)
                local distWidth = Theme.getFont(Theme.fonts.tiny):getWidth(distText)
                love.graphics.printf(distText, centerX - distWidth/2, statY, distWidth, "left")
                statY = statY + lineHeight
            end
        end

        -- Hull health
        if targetHull then
            local healthPercent = (targetHull.current / targetHull.max) * 100
            local healthText = string.format("HULL: %.0f%%", healthPercent)
            local healthWidth = Theme.getFont(Theme.fonts.tiny):getWidth(healthText)
            love.graphics.printf(healthText, centerX - healthWidth/2, statY, healthWidth, "left")
            statY = statY + lineHeight
        end

        -- Shield status
        local targetShield = ECS.getComponent(input.targetedEnemy, "Shield")
        if targetShield and targetShield.max > 0 then
            local shieldPercent = (targetShield.current / targetShield.max) * 100
            local shieldText = string.format("SHLD: %.0f%%", shieldPercent)
            local shieldWidth = Theme.getFont(Theme.fonts.tiny):getWidth(shieldText)
            love.graphics.printf(shieldText, centerX - shieldWidth/2, statY, shieldWidth, "left")
            statY = statY + lineHeight
        end

        -- Weapon type
        local targetTurret = ECS.getComponent(input.targetedEnemy, "Turret")
        if targetTurret and targetTurret.moduleName then
            local weaponText = string.format("WEAP: %s", targetTurret.moduleName:gsub("_", " "):upper())
            local weaponWidth = Theme.getFont(Theme.fonts.tiny):getWidth(weaponText)
            love.graphics.printf(weaponText, centerX - weaponWidth/2, statY, weaponWidth, "left")
            statY = statY + lineHeight
        end

        -- Speed
        local targetVelocity = ECS.getComponent(input.targetedEnemy, "Velocity")
        if targetVelocity then
            local speed = math.sqrt(targetVelocity.vx * targetVelocity.vx + targetVelocity.vy * targetVelocity.vy)
            local speedText = string.format("SPD: %.0f u/s", speed)
            local speedWidth = Theme.getFont(Theme.fonts.tiny):getWidth(speedText)
            love.graphics.printf(speedText, centerX - speedWidth/2, statY, speedWidth, "left")
        end
    elseif isTargeting then
        -- Show targeting progress during lock-on
        local targetPos = ECS.getComponent(input.targetingTarget, "Position")

        -- Draw targeting reticle/bracket (yellow/orange during targeting)
        love.graphics.setColor(1, 0.8, 0.2, 0.8)  -- Orange targeting color
        love.graphics.setLineWidth(2)

        local reticleSize = 15
        -- Draw corner brackets
        love.graphics.line(centerX - reticleSize, y, centerX - reticleSize/2, y)
        love.graphics.line(centerX - reticleSize, y, centerX - reticleSize, y + reticleSize/2)
        love.graphics.line(centerX + reticleSize, y, centerX + reticleSize/2, y)
        love.graphics.line(centerX + reticleSize, y, centerX + reticleSize, y + reticleSize/2)

        -- Draw pulsing center dot (faster pulse during targeting)
        local time = love.timer.getTime()
        local pulse = 0.3 + 0.4 * math.sin(time * 10)
        love.graphics.setColor(1, 0.8, 0.2, pulse)
        love.graphics.circle("fill", centerX, y + reticleSize/2, 3)

        -- Draw progress bar
        local barWidth = 80
        local barHeight = 6
        local barX = centerX - barWidth / 2
        local barY = y + reticleSize + 5

        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 2, 2)

        -- Progress fill
        local progressWidth = barWidth * input.targetingProgress
        love.graphics.setColor(1, 0.8, 0.2, 0.9)
        love.graphics.rectangle("fill", barX, barY, progressWidth, barHeight, 2, 2)

        -- Border
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 2, 2)

        -- Draw "TARGETING..." text
        love.graphics.setColor(Theme.colors.textPrimary)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        local text = "TARGETING..."
        local textWidth = Theme.getFont(Theme.fonts.small):getWidth(text)
        love.graphics.printf(text, centerX - textWidth/2, y + reticleSize + 15, textWidth, "left")

        -- Show progress percentage
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local progressText = string.format("%.1f%%", input.targetingProgress * 100)
        local progressWidth = Theme.getFont(Theme.fonts.tiny):getWidth(progressText)
        love.graphics.printf(progressText, centerX - progressWidth/2, y + reticleSize + 30, progressWidth, "left")

    else
        -- Show "NO TARGET" when no enemy is targeted
        love.graphics.setColor(Theme.colors.textSecondary)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        local text = "NO TARGET"
        local textWidth = Theme.getFont(Theme.fonts.small):getWidth(text)
        love.graphics.printf(text, centerX - textWidth/2, y, textWidth, "left")

        -- Add hint text
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local hintText = "CTRL + CLICK to target enemy (3s lock-on)"
        local hintWidth = Theme.getFont(Theme.fonts.tiny):getWidth(hintText)
        love.graphics.printf(hintText, centerX - hintWidth/2, y + 20, hintWidth, "left")

        -- Add note about mouse freedom
        local noteText = "Mouse can move freely during lock-on"
        local noteWidth = Theme.getFont(Theme.fonts.tiny):getWidth(noteText)
        love.graphics.printf(noteText, centerX - noteWidth/2, y + 35, noteWidth, "left")
    end
end

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


local function drawHotkeyOverlay(viewportWidth, viewportHeight)
    -- Draw hotkey overlay in bottom left
    local x = Scaling.scaleX(20)
    local y = viewportHeight - Scaling.scaleY(180)  -- Position from bottom (moved up a bit)

    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    local overlayWidth = Scaling.scaleSize(200)
    local overlayHeight = Scaling.scaleSize(140)  -- Increased for 6 lines instead of 4
    love.graphics.rectangle("fill", x - 10, y - 10, overlayWidth, overlayHeight, 4, 4)

    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x - 10, y - 10, overlayWidth, overlayHeight, 4, 4)

    -- Hotkey text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))

    local lineHeight = 14
    local currentY = y

    love.graphics.print("WASD: Move", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("TAB: Cargo Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("V: Skills Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("G: Ship Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("F5: Toggle HUD", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("ESC: Quit", x, currentY)
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

    -- Draw targeting indicator first (top layer)
    drawTargetingIndicator(viewportWidth, viewportHeight)

    drawHullShieldBar(viewportWidth, viewportHeight)
    drawTurretSlots(viewportWidth, viewportHeight)
    -- drawMagneticFieldStatus(viewportWidth, viewportHeight) -- Removed magnetic field HUD
    -- Draw minimap as part of HUD
    if Minimap and Minimap.draw then
        Minimap.draw()
    end
    drawSpeedText(viewportWidth, viewportHeight)

    -- Draw hotkey overlay
    drawHotkeyOverlay(viewportWidth, viewportHeight)

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
