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

                -- Plasma theme background (darker energy-infused background)
                local bgColor = {0.05, 0.05, 0.08, 0.95}
                love.graphics.setColor(bgColor)
                local cornerRadius = 4 * scaleU
                love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)

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
                        if not module or not module.draw or not module.design or not module.design.size then
                            goto skip_turret_rendering
                        end

                        -- Draw turret icon (scaled down)
                        love.graphics.push()
                        local iconScale = scaleU * 0.6  -- Slightly smaller for better fit
                        love.graphics.scale(iconScale, iconScale)
                        local iconX = (slotX + slotWidth / 2) / iconScale
                        local iconY = (slotY + slotHeight / 2) / iconScale
                        love.graphics.translate(iconX - module.design.size / 2, iconY - module.design.size / 2)
                        module.draw(module, 0, 0)
                        love.graphics.pop()

                        -- Draw cooldown/heat bar background
                        local barWidth = slotWidth - 6 * scaleX
                        local barHeight = 3 * scaleY
                        local barX = slotX + 3 * scaleX
                        local barY = slotY + slotHeight - barHeight - 3 * scaleY

                        -- Background bar (dark with slight transparency)
                        love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 1, 1)

                        -- Calculate and draw cooldown/heat progress
                        local progress = 0
                        local barColor = {0.2, 0.8, 1.0, 1.0} -- Default cyan

                        if module.CONTINUOUS then
                            -- Continuous weapons (lasers) - use heat system
                            if turretComp and turretComp.heat then
                                local heat = turretComp.heat
                                local maxHeat = module.MAX_HEAT or 10

                                if heat.current >= maxHeat then
                                    -- In cooldown state
                                    local cooldownProgress = heat.cooldownTimer or 0
                                    local cooldownDuration = 2.0 -- 2 second cooldown
                                    progress = cooldownProgress / cooldownDuration
                                    barColor = {1.0, 0.2, 0.1, 1.0} -- Red for cooldown
                                else
                                    -- Normal heat
                                    progress = heat.current / maxHeat
                                    barColor = {1.0, 0.7, 0.1, 1.0} -- Yellow-orange for heat
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

                        -- Draw progress bar with rounded corners
                        if progress > 0 then
                            love.graphics.setColor(barColor)
                            love.graphics.rectangle("fill", barX + 1, barY + 1, (barWidth - 2) * progress, barHeight - 2, 1, 1)

                            -- Add subtle glow effect
                            love.graphics.setColor(barColor[1], barColor[2], barColor[3], 0.3)
                            love.graphics.rectangle("fill", barX - 1, barY - 1, (barWidth + 2) * progress, barHeight + 2, 2, 2)
                        end

                        -- Draw border with subtle outline
                        love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                        love.graphics.setLineWidth(1)
                        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 1, 1)
                        love.graphics.setLineWidth(1)

                        -- Check for mouse hover (using screen coordinates since canvas is drawn in screen space)
                        local mouseX, mouseY = love.mouse.getPosition()

                        -- Convert canvas coordinates to screen coordinates for hover detection
                        local screenSlotX = drawX + slotX
                        local screenSlotY = drawY + slotY

                        if mouseX >= screenSlotX and mouseX < screenSlotX + slotWidth and
                           mouseY >= screenSlotY and mouseY < screenSlotY + slotHeight then

                            -- Set hover data for tooltip
                            if hudSystem then
                                hudSystem.hoveredTurretSlot = {
                                    itemId = itemId,
                                    itemDef = itemDef,
                                    mouseX = mouseX,
                                    mouseY = mouseY
                                }
                            end

                            -- Add hover effect
                            love.graphics.setColor(1.0, 1.0, 1.0, 0.3)
                            love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, cornerRadius, cornerRadius)
                        end
                        end

                        ::skip_turret_rendering::

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

    local drawX = (Scaling.getCurrentWidth() - turretSlotsCanvasW) / 2
    local drawY = Scaling.getCurrentHeight() - turretSlotsCanvasH - 20
    BatchRenderer.queueCanvas(turretSlotsCanvas, drawX, drawY, 1, 1, 1, 1)

    -- Clear hover data when not hovering
    if hudSystem then
        hudSystem.hoveredTurretSlot = nil
    end
end

return HUDSlots
