---@diagnostic disable: undefined-global
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

            for slotIndex = 1, 3 do
                local slotX = startX + (slotIndex - 1) * (slotWidth + slotSpacing)
                local slotY = startY

                -- Plasma theme background (neutral dark background)
                local bgColor = {0.05, 0.05, 0.08, 0.95}
                love.graphics.setColor(bgColor)
                -- No rounded corners: set corner radius to 0
                local cornerRadius = 0
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

                -- Draw progress overlay using the entire slot area (fills proportionally)
                -- Only show progress bar when NOT overheated (during cooldown, only show red blinking)
                if progress > 0 and not isOverheated then
                    -- Inner padding so slot border is still visible
                    local pad = 2 * scaleX
                    local innerX = slotX + pad
                    local innerY = slotY + pad
                    local innerW = slotWidth - pad * 2
                    local innerH = slotHeight - pad * 2

                    -- Inner background
                    love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, cornerRadius, cornerRadius)

                    -- Fill the inner area proportionally (bottom-up)
                    local fillH = math.max(2, (innerH - 2) * progress)
                    local fillX = innerX + 1
                    local fillY = innerY + (innerH - fillH) - 1

                    love.graphics.setColor(barColor)
                    love.graphics.rectangle("fill", fillX, fillY, innerW - 2, fillH, 0, 0)

                    -- Inner border
                    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", innerX, innerY, innerW, innerH, cornerRadius, cornerRadius)
                    love.graphics.setLineWidth(1)
                end

                -- Overheat cooldown: solid red bar that empties from top to bottom
                if isOverheated then
                    local pad = 2 * scaleX
                    local innerX = slotX + pad
                    local innerY = slotY + pad
                    local innerW = slotWidth - pad * 2
                    local innerH = slotHeight - pad * 2

                    -- Draw inner background
                    love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, cornerRadius, cornerRadius)

                    -- Draw red fill representing remaining cooldown (empties top -> bottom)
                    local rem = math.max(0, 1 - (progress or 0))
                    local fillH = math.max(2, (innerH - 2) * rem)
                    local fillX = innerX + 1
                    -- Anchor fill to bottom so it empties top-down
                    local fillY = innerY + (innerH - fillH) - 1

                    love.graphics.setColor(1.0, 0.2, 0.1, 1.0) -- Solid red
                    love.graphics.rectangle("fill", fillX, fillY, innerW - 2, fillH, 0, 0)

                    -- Inner border
                    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", innerX, innerY, innerW, innerH, cornerRadius, cornerRadius)
                    love.graphics.setLineWidth(1)
                end

                -- Plasma theme borders with thick black outlines
                -- Use thin white border for all slots
                local borderColor = {1.0, 1.0, 1.0, 1.0}
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 0, 0)

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
                    -- No central circle design for empty slots
                end
            end
        end)
        lastTurretSlotsFrame = frameSkip
    end

    if hudSystem then
        hudSystem.hoveredTurretSlot = nil
    end

    -- Queue the canvas for rendering
    -- Queue turret slots as overlay so they render above world-space HUD bars
    BatchRenderer.queueCanvas(turretSlotsCanvas, drawX, drawY, 1, 1, 1, 1, "overlay")

    -- Handle mouse hover detection and effects every frame
    local mouseX, mouseY = love.mouse.getPosition()

    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            local droneId = input.targetEntity
            local turretSlots = ECS.getComponent(droneId, "TurretSlots")
            if turretSlots then
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
                            -- No rounded corners for hover effect
                            local cornerRadius = 0
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

return HUDSlots
