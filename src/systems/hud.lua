---@diagnostic disable: undefined-global
-- HUD System - Always-on HUD elements (speed, hull/shield)

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local Tooltips = require('src.ui.tooltips')
local TurretSystem = require('src.systems.turret')
local TimeManager = require('src.time_manager')

local HUDSystem = {
    name = "HUDSystem",
    -- HUD should be drawn inside the canvas (screen-space overlay)
    visible = true, -- HUD is visible by default, force true on load
    hoveredTurretSlot = nil -- Track which turret slot is being hovered
}

-- Replace drawTargetingIndicator to only show a panel if an enemy is targeted, with a theme-styled boxed layout, or nothing otherwise
local function drawTargetingPanel(viewportWidth, viewportHeight)
    local ECS = require('src.ecs')
    local Theme = require('src.ui.theme')
    local Scaling = require('src.scaling')
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetedEnemy then return end
    local entity = input.targetedEnemy
    local targetPos = ECS.getComponent(entity, "Position")
    local targetHull = ECS.getComponent(entity, "Hull")
    local targetShield = ECS.getComponent(entity, "Shield")
    local targetTurret = ECS.getComponent(entity, "Turret")
    local targetVelocity = ECS.getComponent(entity, "Velocity")
    local playerEntity = input.targetEntity
    local playerPos = playerEntity and ECS.getComponent(playerEntity, "Position")
    -- Panel dimensions
    local panelW, panelH = Scaling.scaleSize(308), Scaling.scaleSize(124)
    local centerX = viewportWidth / 2
    local posX = centerX - panelW / 2
    local posY = Theme.spacing.margin + 8
    -- Draw panel background and border
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", posX, posY, panelW, panelH, Theme.spacing.padding * 2)
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", posX, posY, panelW, panelH, Theme.spacing.padding * 2)
    -- Fonts and layout math
    local smallFont = Theme.getFont(Theme.fonts.small)
    local normalFont = Theme.getFont(Theme.fonts.normal)
    love.graphics.setFont(normalFont)
    local col1 = posX + Theme.spacing.padding * 2
    local col2 = posX + panelW * 0.54
    local row = posY + Theme.spacing.padding * 2 + Scaling.scaleY(10)
    local rowH = Scaling.scaleSize(18)
    local barW = panelW - Theme.spacing.padding * 4
    local barH = Scaling.scaleSize(22)
    -- First row: Target type/name
    local enemyType = "Unknown"
    if ECS.hasComponent(entity, "CombatAI") then enemyType = "Combat" end
    if ECS.hasComponent(entity, "MiningAI") then enemyType = "Mining" end
    if ECS.hasComponent(entity, "MagneticField") then enemyType = "Collector" end
        love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print("Target: "..enemyType, col1, row)
    -- Hull/Shield bar below type row
    row = row + rowH + Scaling.scaleY(4)
    local hullVal = targetHull and targetHull.current or 0
    local hullMax = targetHull and targetHull.max or 1
    local shieldVal = (targetShield and targetShield.current) or 0
    local shieldMax = (targetShield and targetShield.max) or 0
    -- Draw segmented hull+shield bar like player HUD (hull base, shield overlay, then border)
    local hullRatio = math.min(hullVal / hullMax, 1.0)
    local fillWidth = barW * hullRatio
    local x = col1
    local y = row
    -- Background parallelogram
    local skew = Scaling.scaleSize(13)
    love.graphics.setColor(0.14, 0.15, 0.2, 0.85)
    love.graphics.polygon("fill", x, y, x + barW + skew, y, x + barW, y + barH, x - skew, y + barH)
    -- Hull fill parallelogram
    love.graphics.setColor(1.0, 0.2, 0.2, 0.88)
    love.graphics.polygon("fill", x, y, x + fillWidth + skew * hullRatio, y, x + fillWidth, y + barH, x - skew * hullRatio, y + barH)
    -- Shield overlay
    if shieldMax > 0 and shieldVal > 0 then
        local sRatio = math.min(shieldVal / shieldMax, 1.0)
        local sFill = barW * sRatio
        love.graphics.setColor(0.22, 0.74, 1, 0.80)
        love.graphics.polygon("fill", x, y, x + sFill + skew * sRatio, y, x + sFill, y + barH, x - skew * sRatio, y + barH)
    end
    -- Bar border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.setLineWidth(1.1)
    love.graphics.polygon("line", x, y, x + barW + skew, y, x + barW, y + barH, x - skew, y + barH)
    -- Bar text (centered)
    local barText
    if shieldMax > 0 then
        barText = string.format("Hull %d/%d   Shield %d/%d", hullVal, hullMax, shieldVal, shieldMax)
    else
        barText = string.format("Hull %d/%d", hullVal, hullMax)
    end
    love.graphics.setFont(smallFont)
    local barTextW = smallFont:getWidth(barText)
    local barTextX = x + (barW - barTextW) / 2
    local barTextY = y + (barH - smallFont:getHeight()) / 2
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(barText, barTextX, barTextY)
    -- Draw other stats below the bar
    row = row + barH + Scaling.scaleY(6)
    love.graphics.setFont(normalFont)
        -- Distance
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.print("Distance:", col1, row)
    love.graphics.setColor(Theme.colors.textAccent)
    if playerPos and targetPos then
        local dx, dy = targetPos.x - playerPos.x, targetPos.y - playerPos.y
        love.graphics.print(string.format("%.0f u", math.sqrt(dx*dx+dy*dy)), col2, row)
    else
        love.graphics.print("-", col2, row)
    end
    row = row + rowH
        -- Speed
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.print("Speed:", col1, row)
    love.graphics.setColor(Theme.colors.textAccent)
        if targetVelocity then
        local speed = math.sqrt((targetVelocity.vx or 0)^2 + (targetVelocity.vy or 0)^2)
        love.graphics.print(string.format("%.0f u/s", speed), col2, row)
    else
        love.graphics.print("0 u/s", col2, row)
    end
    row = row + rowH
    -- Weapon
    love.graphics.setColor(Theme.colors.textSecondary)
    love.graphics.print("Weapon:", col1, row)
    love.graphics.setColor(Theme.colors.textAccent)
    if targetTurret and targetTurret.moduleName then
        love.graphics.print(targetTurret.moduleName:gsub("_", " "):upper(), col2, row)
    else
        love.graphics.print("None", col2, row)
    end
end

local function drawFpsCounter(viewportWidth, viewportHeight)
    -- Draw FPS in top-right corner
    local fps = TimeManager.getFps()
    local targetFps = TimeManager.getTargetFps()
    
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    
    -- Build FPS text
    local fpsText = string.format("FPS: %d", fps)
    if targetFps then
        fpsText = fpsText .. string.format(" / %d", targetFps)
    else
        fpsText = fpsText .. " (Unlocked)"
    end
    
    -- Color based on performance
    local color = Theme.colors.textPrimary
    if targetFps then
        if fps >= targetFps * 0.95 then
            color = {0.2, 1, 0.2, 0.8} -- Green: good
        elseif fps >= targetFps * 0.7 then
            color = {1, 1, 0.2, 0.8} -- Yellow: okay
        else
            color = {1, 0.2, 0.2, 0.8} -- Red: bad
        end
    else
        -- Unlocked FPS - show in cyan
        color = {0.2, 0.8, 1, 0.8}
    end
    
    love.graphics.setColor(color)
    
    local textWidth = Theme.getFont(Theme.fonts.tiny):getWidth(fpsText)
    local x = viewportWidth - textWidth - 10
    local y = 10
    
    love.graphics.print(fpsText, x, y)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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
    local y = viewportHeight - Scaling.scaleY(200)  -- Position from bottom (moved up a bit)

    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    local overlayWidth = Scaling.scaleSize(240)
    local overlayHeight = Scaling.scaleSize(160)  -- Increased for 7 lines
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
    love.graphics.print("Ctrl+Click: Target", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("Escape: Clear Target", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("TAB: Cargo Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("V: Skills Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("G: Ship Window", x, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("F5: Toggle HUD", x, currentY)
end

-- Canvas caching for turret slots
local turretSlotsCanvas, turretSlotsCanvasW, turretSlotsCanvasH, lastTurretSlotsFrame = nil, nil, nil, nil

local function drawTurretSlots(viewportWidth, viewportHeight)
    -- Throttle: update only every other frame, otherwise reuse Canvas
    local frameSkip = math.floor(love.timer.getTime() * 30)
    local updateNow = (not lastTurretSlotsFrame) or (frameSkip % 2 == 0)
    local canvasW, canvasH = Scaling.scaleSize(180), Scaling.scaleSize(64)  -- Enough for 3 slots
    turretSlotsCanvasW, turretSlotsCanvasH = canvasW, canvasH
    if not turretSlotsCanvas then
        turretSlotsCanvas = love.graphics.newCanvas(canvasW, canvasH)
    end

    if updateNow then
        turretSlotsCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            ---------------------------------------------------------
            local ECS = require('src.ecs')
            local Constants = require('src.constants')
            local Scaling = require('src.scaling')
            local TurretSystem = require('src.systems.turret')
            local TurretRange = require('src.systems.turret_range')
            local ItemDefs = require('src.items.item_loader')

    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    
    local droneId = input.targetEntity
    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    if not turretSlots then return end
    
    local slotSize = Scaling.scaleSize(48)
    local slotSpacing = Scaling.scaleSize(8)
            local startX = 0  -- Drawing to canvas, always start at 0
            local startY = 0
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local turret = ECS.getComponent(droneId, "Turret")
    
    -- Reset hover tracking
    HUDSystem.hoveredTurretSlot = nil
    -- Draw up to 3 slots
    for slotIndex = 1, 3 do
        local slotX = startX + (slotIndex - 1) * (slotSize + slotSpacing)
        local slotY = startY
    -- Draw slot background
                local bgColor = {0.1, 0.1, 0.15, 0.9}
                love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
        -- Draw slot border
        local borderColor = {0.4, 0.4, 0.5, 0.8}
                if turretSlots.slots[slotIndex] then borderColor = {0.2, 0.8, 1.0, 1.0} end
                love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
        love.graphics.setLineWidth(1)
        -- Draw equipped module icon or placeholder
        if turretSlots.slots[slotIndex] then
                    local itemId = turretSlots.slots[slotIndex]
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.draw then
                love.graphics.setColor(1, 1, 1, 1)
                        local ok = pcall(itemDef.module.draw, itemDef.module, slotX + slotSize / 2, slotY + slotSize / 2)
                if not ok then
                    love.graphics.setColor(0.5, 0.5, 0.8, 1)
                    love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
                end
            elseif itemDef and itemDef.draw then
                    love.graphics.setColor(1, 1, 1, 1)
                    itemDef:draw(slotX + slotSize / 2, slotY + slotSize / 2)
            else
                love.graphics.setColor(0.5, 0.5, 0.8, 1)
                love.graphics.circle("fill", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 3)
            end
                    -- Heat overlays (laser turrets only)
            if slotIndex == 1 and turret then
                local moduleName = turret.moduleName
                local module = moduleName and TurretSystem.turretModules[moduleName]
                local isLaserTurret = moduleName == "mining_laser" or moduleName == "combat_laser" or moduleName == "salvage_laser"
                if module and module.CONTINUOUS and isLaserTurret then
                    local heat = turret.heat
                    if heat then
                        local heatVal = (heat.current or 0)
                        local maxHeat = module.MAX_HEAT or 10
                        local isInCooldown = heatVal >= maxHeat
                        
                        if isInCooldown then
                            -- Blinking red during cooldown
                            local cooldownTimer = heat.cooldownTimer or 0
                            local blinkPhase = math.floor((cooldownTimer * 4)) % 2  -- Blinks 4 times per second
                            if blinkPhase == 0 then
                                love.graphics.setColor(1.0, 0.2, 0.2, 0.8)  -- Bright red
                                local pad = math.max(2, math.floor(slotSize * 0.08))
                                local innerH = slotSize - pad * 2
                                local innerW = slotSize - pad * 2
                                love.graphics.rectangle("fill", slotX + pad, slotY + pad, innerW, innerH, 3, 3)
                            end
                        else
                            -- Normal heat bar when not in cooldown
                            local heatRatio = heatVal / maxHeat
                            local pad = math.max(2, math.floor(slotSize * 0.08))
                            local innerH = slotSize - pad * 2
                            local innerW = slotSize - pad * 2
                            local overlayInnerWidth = math.floor(innerW * heatRatio)
                            love.graphics.setColor(0.9, 0.3, 0.2, 0.4)  -- Orange heat bar
                            if overlayInnerWidth > 0 then
                                love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                            end
                        end
                    end
                elseif module then
                        local moduleCooldown = TurretRange.getFireCooldown(moduleName)
                        local currentTime = love.timer.getTime()
                        local timeSinceLastFire = currentTime - (turret.lastFireTime or 0)
                        local cooldownRatio = math.max(0, math.min(timeSinceLastFire / moduleCooldown, 1.0))
                        local pad = math.max(2, math.floor(slotSize * 0.08))
                        local innerH = slotSize - pad * 2
                        local innerW = slotSize - pad * 2
                        local overlayInnerWidth = math.floor(innerW * cooldownRatio)
                            love.graphics.setColor(0.2, 0.8, 0.2, 0.28)
                        if overlayInnerWidth > 0 then
                            love.graphics.rectangle("fill", slotX + pad, slotY + pad, overlayInnerWidth, innerH, 3, 3)
                    end
                end
            end
        else
            love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
            love.graphics.circle("line", slotX + slotSize / 2, slotY + slotSize / 2, slotSize / 4)
        end
    end
            ---------------------------------------------------------
        end)
        lastTurretSlotsFrame = frameSkip
    end
    -- Main draw: blit the cached canvas to global HUD location (bottom center)
    local drawX = (viewportWidth - turretSlotsCanvasW) / 2
    local drawY = viewportHeight - turretSlotsCanvasH - Scaling.scaleY(20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(turretSlotsCanvas, drawX, drawY)
end


local Minimap = require('src.systems.minimap')

-- HUDSystem.visible = true -- HUD is visible by default

function HUDSystem.toggle()
    HUDSystem.visible = not HUDSystem.visible
end

-- HUD Full Canvas Caching
local hudCanvas, hudCanvasW, hudCanvasH, lastHudCanvasFrame, lastHudStateHash = nil, nil, nil, nil, nil

-- Utility to create a hash of the relevant HUD data tuple
local function valn(x, def)
    if x == nil then return def or 0 end
    return x
end
local function getHudStateHash()
    local ECS = require('src.ecs')
    local Minimap = require('src.systems.minimap')
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return "none" end
    local p = playerEntities[1]
    local input = ECS.getComponent(p, "InputControlled")
    if not input or not input.targetEntity then return "no_drone" end
    local d = input.targetEntity
    local hull = ECS.getComponent(d, "Hull") or {}
    local shield = ECS.getComponent(d, "Shield") or {}
    local velocity = ECS.getComponent(d, "Velocity") or {}
    local turret = ECS.getComponent(d, "Turret") or {}
    local heat = turret.heat or {}
    local rings = ECS.getComponent(d, "Rings") or {}
    local turretSlots = ECS.getComponent(d, "TurretSlots") or {slots={}}
    local notifLen = #(require('src.ui.notifications').notifications or {})
    local skillNotifLen = #(require('src.ui.skill_notifications').notifications or {})
    local minimapDirty = tostring(Minimap and Minimap._internal and Minimap._internal.UPDATE_INTERVAL_FRAMES or 0)
    -- Values affecting main HUD visuals:
    return table.concat({
        valn(hull.current), valn(hull.max), valn(shield.current), valn(shield.max),
        valn(velocity.vx), valn(velocity.vy), valn(velocity.vz),
        valn(turret.moduleName, ''), valn(heat.current),
        valn(turret.lastFireTime),
        valn(turretSlots.slots and turretSlots.slots[1], ''),
        valn(turretSlots.slots and turretSlots.slots[2], ''),
        valn(turretSlots.slots and turretSlots.slots[3], ''),
        notifLen, skillNotifLen, minimapDirty
    },":")
end

local function drawHudCanvasContents(viewportWidth, viewportHeight)
    drawHullShieldBar(viewportWidth, viewportHeight)
    drawTurretSlots(viewportWidth, viewportHeight)
    if Minimap and Minimap.draw then Minimap.draw() end
    drawSpeedText(viewportWidth, viewportHeight)
    drawFpsCounter(viewportWidth, viewportHeight)
    drawHotkeyOverlay(viewportWidth, viewportHeight)
    -- Notifications & skills (drawn every other frame for fade)
    local frameSkip = math.floor(love.timer.getTime() * 30)
    if frameSkip % 2 == 0 then
        local Notifications = require('src.ui.notifications')
        local SkillNotifications = require('src.ui.skill_notifications')
        Notifications.draw(0, 0, 1)
        SkillNotifications.draw()
    end
end

function HUDSystem.draw(viewportWidth, viewportHeight)
    if not HUDSystem.visible then return end
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080
    -- Only allocate if resolution changes
    if not hudCanvas or hudCanvasW ~= viewportWidth or hudCanvasH ~= viewportHeight then
        hudCanvasW, hudCanvasH = viewportWidth, viewportHeight
        hudCanvas = love.graphics.newCanvas(hudCanvasW, hudCanvasH)
        lastHudCanvasFrame = nil
        lastHudStateHash = nil
    end
    -- State hash approach: redraw HUD only if values change or every N frames (just in case)
    local redrawIntervalFrames = 3
    local frameSkip = math.floor(love.timer.getTime() * 30)
    local hudStateHash = getHudStateHash()
    local shouldRedraw = (lastHudStateHash ~= hudStateHash) or (not lastHudCanvasFrame) or (frameSkip - (lastHudCanvasFrame or 0) >= redrawIntervalFrames)
    if shouldRedraw then
        hudCanvas:renderTo(function()
            love.graphics.clear(0,0,0,0)
            drawHudCanvasContents(viewportWidth, viewportHeight)
        end)
        lastHudCanvasFrame = frameSkip
        lastHudStateHash = hudStateHash
    end
    -- Draw cached HUD
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(hudCanvas, 0, 0)
    -- Draw overlays (targeting indicator/crosshair/tooltips)
    drawTargetingPanel(viewportWidth, viewportHeight)
    -- Tooltip popup
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
