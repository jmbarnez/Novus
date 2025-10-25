-- HUD Slots Module - Turret slot rendering

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local TurretSystem = require('src.systems.turret')
local TurretRange = require('src.systems.turret_range')
local ItemDefs = require('src.items.item_loader')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDSlots = {}

-- Canvas caching for turret slots
local turretSlotsCanvas, turretSlotsCanvasW, turretSlotsCanvasH, lastTurretSlotsFrame = nil, nil, nil, nil

function HUDSlots.drawTurretSlots(viewportWidth, viewportHeight, hudSystem)
    local frameSkip = math.floor(love.timer.getTime() * 30)
    local updateNow = (not lastTurretSlotsFrame) or (frameSkip % 2 == 0)

    local scaleX = Scaling.canvasScaleX or 1
    local scaleY = Scaling.canvasScaleY or 1
    local scaleU = math.min(scaleX, scaleY)

    local canvasW = math.ceil(180 * scaleX)
    local canvasH = math.ceil(64 * scaleY)

    if turretSlotsCanvasW ~= canvasW or turretSlotsCanvasH ~= canvasH then
        if turretSlotsCanvas then
            turretSlotsCanvas:release()
        end
        turretSlotsCanvas = nil
    end

    turretSlotsCanvasW, turretSlotsCanvasH = canvasW, canvasH

    -- Calculate canvas position (needed for hover detection)
    local drawX = (Scaling.getCurrentWidth() - turretSlotsCanvasW) / 2
    local drawY = Scaling.getCurrentHeight() - turretSlotsCanvasH - 20

    if not turretSlotsCanvas then
        turretSlotsCanvas = love.graphics.newCanvas(canvasW, canvasH)
    end

    if updateNow then
        turretSlotsCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)

            local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
            if #playerEntities == 0 then return end
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if not input or not input.targetEntity then return end

            local droneId = input.targetEntity
            local turretSlots = ECS.getComponent(droneId, "TurretSlots")
            if not turretSlots then return end

            local slotWidth = 48 * scaleX
            local slotHeight = 48 * scaleY
            local slotSpacing = 8 * scaleX
            local startX = 0
            local startY = 0

            local turret = ECS.getComponent(droneId, "Turret")

            if hudSystem then
                hudSystem.hoveredTurretSlot = nil
            end

            for slotIndex = 1, 3 do
                local slotX = startX + (slotIndex - 1) * (slotWidth + slotSpacing)
                local slotY = startY

                -- Plasma theme background (neutral dark background)
                local bgColor = {0.05, 0.05, 0.08, 0.95}
                love.graphics.setColor(bgColor)
                local cornerRadius = 4 * scaleU
                love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)

                -- Calculate heat/cooldown state for progress bar
                local progress = 0
                local barColor = {0.2, 0.8, 1.0, 1.0} -- Default cyan
                local isOverheated = false
                local isBlinking = false

                if turretSlots.slots[slotIndex] then
                    local itemId = turretSlots.slots[slotIndex]
                    local itemDef = ItemDefs[itemId]

                    if itemDef and itemDef.module then
                        local module = itemDef.module
                        local turretComp = turret

                        -- Safety check for module draw function
                        if module and module.draw and module.design and module.design.size then

                            -- Calculate heat/cooldown state
                            if module.CONTINUOUS then
                                -- Continuous weapons (lasers) - use heat system
                                if turretComp and turretComp.heat then
                                    local heat = turretComp.heat
                                    local maxHeat = module.MAX_HEAT or 10

                                    if heat.current >= maxHeat then
                                        -- In cooldown state (overheated)
                                        isOverheated = true
                                        local cooldownProgress = heat.cooldownTimer or 0
                                        local cooldownDuration = 2.0 -- 2 second cooldown
                                        progress = cooldownProgress / cooldownDuration
                                        barColor = {1.0, 0.2, 0.1, 1.0} -- Red for overheat

                                        -- Add blinking effect (once per second)
                                        local blinkRate = 1.0 -- 1 second interval
                                        local currentTime = love.timer.getTime()
                                        isBlinking = math.floor(currentTime * blinkRate) % 2 == 0
                                    else
                                        -- Normal heat
                                        progress = heat.current / maxHeat
                                        local heatRatio = progress
                                        barColor = {
                                            1.0, -- Red component
                                            0.7, -- Green component (less than red for orange)
                                            0.1, -- Blue component
                                            1.0
                                        }
                                    end
                                end
                            else
                                -- Discrete weapons (projectiles) - use cooldown timer
                                if turretComp then
                                    local cooldown = TurretRange.getFireCooldown(module.name or itemId:gsub("_turret", ""))
                                    local currentTime = love.timer.getTime()
                                    local timeSinceLastFire = currentTime - (turretComp.lastFireTime or 0)

                                    if timeSinceLastFire < cooldown then
                                        progress = timeSinceLastFire / cooldown
                                        barColor = {0.1, 0.6, 1.0, 1.0} -- Blue for cooldown
                                    else
                                        progress = 1.0 -- Ready to fire
                                        barColor = {0.1, 1.0, 0.2, 1.0} -- Green when ready
                                    end
                                end
                            end
                        end
                    end
                end

                -- Draw progress bar at the bottom of the slot
                if progress > 0 then
                    local barWidth = slotWidth - 8 * scaleX
                    local barHeight = 4 * scaleY
                    local barX = slotX + 4 * scaleX
                    local barY = slotY + slotHeight - barHeight - 4 * scaleY

                    -- Apply blinking effect for overheated weapons
                    if isOverheated and isBlinking then
                        barColor[4] = 0.3 -- Reduce opacity for blinking effect
                    end

                    -- Progress bar background
                    love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 1, 1)

                    -- Progress bar fill
                    love.graphics.setColor(barColor)
                    love.graphics.rectangle("fill", barX + 1, barY + 1, (barWidth - 2) * progress, barHeight - 2, 1, 1)

                    -- Progress bar border
                    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 1, 1)
                    love.graphics.setLineWidth(1)
                end

                -- Plasma theme borders with thick black outlines
                local borderColor = {0.2, 0.4, 0.6, 0.8}  -- Default plasma blue
                if turretSlots.slots[slotIndex] then
                    borderColor = {0.2, 0.8, 1.0, 1.0}  -- Bright cyan when occupied
                end
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(PlasmaTheme.colors.outlineThick * scaleU)
                love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)
                love.graphics.setLineWidth(1)

                if turretSlots.slots[slotIndex] then
                    local itemId = turretSlots.slots[slotIndex]
                    local itemDef = ItemDefs[itemId]

                    if itemDef and itemDef.module then
                        local module = itemDef.module
                        local turretComp = turret

                        -- Safety check for module draw function
                        if module and module.draw and module.design and module.design.size then

                            -- Draw turret icon (centered and scaled to fit slot with padding)
                            love.graphics.push()

                            -- Calculate icon size (80% of available space with padding)
                            local padding = 6 * scaleU
                            local availableWidth = slotWidth - padding * 2
                            local availableHeight = slotHeight - padding * 2
                            local iconSize = math.min(availableWidth, availableHeight) * 0.8

                            -- Calculate icon position (centered in slot)
                            local iconX = slotX + padding + (availableWidth - iconSize) / 2
                            local iconY = slotY + padding + (availableHeight - iconSize) / 2

                            -- Translate to icon center and scale
                            love.graphics.translate(iconX + iconSize / 2, iconY + iconSize / 2)
                            love.graphics.scale(iconSize / module.design.size, iconSize / module.design.size)

                            -- Draw the icon
                            module.draw(module, 0, 0)
                            love.graphics.pop()
                        end
                    end

                else
                    -- Plasma energy glow for empty slots
                    love.graphics.setColor(0.1, 0.3, 0.5, 0.6)
                    love.graphics.circle("line", slotX + slotWidth / 2, slotY + slotHeight / 2, math.min(slotWidth, slotHeight) / 4)
                    -- Add inner energy pulse
                    love.graphics.setColor(0.2, 0.4, 0.7, 0.3)
                    love.graphics.circle("fill", slotX + slotWidth / 2, slotY + slotHeight / 2, math.min(slotWidth, slotHeight) / 6)
                end
            end
        end)
        lastTurretSlotsFrame = frameSkip
    end

    -- Queue the canvas for rendering
    BatchRenderer.queueCanvas(turretSlotsCanvas, drawX, drawY, 1, 1, 1, 1)

    -- Handle mouse hover detection and effects (only when canvas was updated)
    if updateNow then
        local mouseX, mouseY = love.mouse.getPosition()

        local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        if #playerEntities > 0 then
            local pilotId = playerEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if input and input.targetEntity then
                local droneId = input.targetEntity
                local turretSlots = ECS.getComponent(droneId, "TurretSlots")
                if turretSlots then
                    local turret = ECS.getComponent(droneId, "Turret")

                    local slotWidth = 48 * scaleX
                    local slotHeight = 48 * scaleY
                    local slotSpacing = 8 * scaleX

                    for slotIndex = 1, 3 do
                        local slotX = (slotIndex - 1) * (slotWidth + slotSpacing)
                        local slotY = 0

                        -- Convert canvas coordinates to screen coordinates for hover detection
                        local screenSlotX = drawX + slotX
                        local screenSlotY = drawY + slotY

                        if mouseX >= screenSlotX and mouseX < screenSlotX + slotWidth and
                           mouseY >= screenSlotY and mouseY < screenSlotY + slotHeight and
                           turretSlots.slots[slotIndex] then

                            local itemId = turretSlots.slots[slotIndex]
                            local itemDef = ItemDefs[itemId]

                            if itemDef then
                                -- Set hover data for tooltip
                                if hudSystem then
                                    hudSystem.hoveredTurretSlot = {
                                        itemId = itemId,
                                        itemDef = itemDef,
                                        mouseX = mouseX,
                                        mouseY = mouseY
                                    }
                                end

                                -- Draw hover effect on top of canvas
                                local cornerRadius = 4 * math.min(scaleX, scaleY)
                                love.graphics.setColor(1.0, 1.0, 1.0, 0.4)
                                love.graphics.rectangle("fill", screenSlotX, screenSlotY, slotWidth, slotHeight, cornerRadius, cornerRadius)

                                love.graphics.setColor(1.0, 1.0, 1.0, 0.8)
                                love.graphics.setLineWidth(2)
                                love.graphics.rectangle("line", screenSlotX, screenSlotY, slotWidth, slotHeight, cornerRadius, cornerRadius)
                                love.graphics.setLineWidth(1)

                                break -- Only one hover at a time
                            end
                        end
                    end
                end
            end
        end
    end
end

return HUDSlots
