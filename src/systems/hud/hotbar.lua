---@diagnostic disable: undefined-global
-- HUD Hotbar Module - renders equipped modules with associated hotkeys

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local ItemDefs = require('src.items.item_loader')
local HotkeyConfig = require('src.hotkey_config')
local TurretRange = require('src.systems.turret_range')
local BatchRenderer = require('src.ui.batch_renderer')

local HUDHotbar = {}

local MAX_SLOTS = 10
local SLOT_ACTIONS = {
    "hotbar_slot_1",
    "hotbar_slot_2",
    "hotbar_slot_3",
    "hotbar_slot_4",
    "hotbar_slot_5",
    "hotbar_slot_6",
    "hotbar_slot_7",
    "hotbar_slot_8",
    "hotbar_slot_9",
    "hotbar_slot_10"
}

local BASE_SLOT_WIDTH = 48
local BASE_SLOT_HEIGHT = 54 -- allow room for hotkey label
local BASE_SLOT_SPACING = 8

local hotbarCanvas, canvasW, canvasH, lastFrameTick = nil, nil, nil, nil

local function getHotkeyLabel(action)
    local key = HotkeyConfig.getHotkey(action)
    if not key or key == "" then
        return "-"
    end
    return HotkeyConfig.formatKey(key)
end

local function collectEquippedModules(droneId)
    local entries = {}

    local function push(itemId, sourceType)
        if not itemId then
            return
        end
        local itemDef = ItemDefs[itemId]
        if not itemDef then
            return
        end
        entries[#entries + 1] = {
            itemId = itemId,
            itemDef = itemDef,
            sourceType = sourceType
        }
    end

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    if turretSlots and turretSlots.slots then
        for slotIndex = 1, (turretSlots.maxSlots or #turretSlots.slots) do
            push(turretSlots.slots[slotIndex], "turret")
        end
    end

    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    if defensiveSlots and defensiveSlots.slots then
        for slotIndex = 1, (defensiveSlots.maxSlots or #defensiveSlots.slots) do
            push(defensiveSlots.slots[slotIndex], "defensive")
        end
    end

    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
    if generatorSlots and generatorSlots.slots then
        for slotIndex = 1, (generatorSlots.maxSlots or #generatorSlots.slots) do
            push(generatorSlots.slots[slotIndex], "generator")
        end
    end

    return entries
end

local function calculateSlotStatus(entry, turretComp)
    local progress = 0
    local color = {0.2, 0.8, 1.0, 1.0}
    local isOverheated = false
    local isBlinking = false

    if not entry or not entry.itemDef then
        return progress, color, isOverheated, isBlinking
    end

    if entry.sourceType ~= "turret" then
        progress = 1.0
        color = {0.1, 1.0, 0.2, 1.0}
        return progress, color, isOverheated, isBlinking
    end

    local module = entry.itemDef.module
    if not module then
        progress = 1.0
        color = {0.1, 1.0, 0.2, 1.0}
        return progress, color, isOverheated, isBlinking
    end

    local isActiveTurret = turretComp and turretComp.moduleName == module.name

    if module.CONTINUOUS then
        if turretComp and turretComp.heat and isActiveTurret then
            local heat = turretComp.heat
            local maxHeat = module.MAX_HEAT or 10
            if heat.current >= maxHeat then
                isOverheated = true
                local cooldownDuration = module.COOLDOWN_TIME or 2.0
                local cooldownTimer = heat.cooldownTimer or 0
                progress = math.min(1.0, cooldownTimer / cooldownDuration)
                color = {1.0, 0.2, 0.1, 1.0}
                local blinkRate = 1.0
                isBlinking = math.floor(love.timer.getTime() * blinkRate) % 2 == 0
            else
                progress = heat.current / maxHeat
                color = {1.0, 0.7, 0.1, 1.0}
            end
        else
            progress = 1.0
            color = {0.1, 1.0, 0.2, 1.0}
        end
        return progress, color, isOverheated, isBlinking
    end

    if not turretComp or not isActiveTurret then
        progress = 1.0
        color = {0.1, 1.0, 0.2, 1.0}
        return progress, color, isOverheated, isBlinking
    end

    local cooldownName = module.name or entry.itemId
    local cooldown = TurretRange.getFireCooldown(cooldownName)
    local currentTime = love.timer.getTime()
    local timeSinceLastFire = currentTime - (turretComp.lastFireTime or 0)
    if timeSinceLastFire < cooldown then
        progress = timeSinceLastFire / cooldown
        color = {0.1, 0.6, 1.0, 1.0}
    else
        progress = 1.0
        color = {0.1, 1.0, 0.2, 1.0}
    end

    return progress, color, isOverheated, isBlinking
end

local function drawModuleIcon(entry, slotX, slotY, slotWidth, slotHeight, scaleU)
    if not entry or not entry.itemDef then
        return
    end

    local padding = 6 * scaleU
    local availableWidth = slotWidth - padding * 2
    local availableHeight = slotHeight - padding * 2
    local iconSize = math.min(availableWidth, availableHeight) * 0.8
    local iconX = slotX + padding + (availableWidth - iconSize) / 2
    local iconY = slotY + padding + (availableHeight - iconSize) / 2

    local drawFn = nil
    local drawContext = nil
    local designSize = nil

    if entry.itemDef.draw then
        drawFn = entry.itemDef.draw
        drawContext = entry.itemDef
        designSize = entry.itemDef.design and entry.itemDef.design.size
    elseif entry.itemDef.module and entry.itemDef.module.draw then
        drawFn = entry.itemDef.module.draw
        drawContext = entry.itemDef.module
        designSize = entry.itemDef.module.design and entry.itemDef.module.design.size
    end

    if not drawFn or not designSize or designSize == 0 then
        return
    end

    love.graphics.push()
    love.graphics.translate(iconX + iconSize / 2, iconY + iconSize / 2)
    love.graphics.scale(iconSize / designSize, iconSize / designSize)
    drawFn(drawContext, 0, 0)
    love.graphics.pop()
end

local function ensureCanvas(width, height)
    if canvasW == width and canvasH == height and hotbarCanvas then
        return
    end

    if hotbarCanvas then
        hotbarCanvas:release()
    end

    hotbarCanvas = love.graphics.newCanvas(width, height)
    canvasW, canvasH = width, height
end

function HUDHotbar.drawHotbar(viewportWidth, viewportHeight, hudSystem)
    local frameTick = math.floor(love.timer.getTime() * 30)
    local shouldUpdate = (not lastFrameTick) or (frameTick % 2 == 0)

    local scaleX = Scaling.canvasScaleX or 1
    local scaleY = Scaling.canvasScaleY or 1
    local scaleU = math.min(scaleX, scaleY)

    local slotWidth = BASE_SLOT_WIDTH * scaleX
    local slotHeight = BASE_SLOT_HEIGHT * scaleY
    local slotSpacing = BASE_SLOT_SPACING * scaleX
    local canvasWidth = math.ceil(slotWidth * MAX_SLOTS + slotSpacing * (MAX_SLOTS - 1))
    local canvasHeight = math.ceil(slotHeight)

    ensureCanvas(canvasWidth, canvasHeight)

    local drawX = (Scaling.getCurrentWidth() - canvasWidth) / 2
    local drawY = Scaling.getCurrentHeight() - canvasHeight - 20

    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local entries = {}
    local turretComp = nil

    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            local droneId = input.targetEntity
            entries = collectEquippedModules(droneId)
            turretComp = ECS.getComponent(droneId, "Turret")
        end
    end

    if shouldUpdate and hotbarCanvas then
        hotbarCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)

            for slotIndex = 1, MAX_SLOTS do
                local slotX = (slotIndex - 1) * (slotWidth + slotSpacing)
                local slotY = 0
                local entry = entries[slotIndex]
                local action = SLOT_ACTIONS[slotIndex]
                local hotkeyLabel = getHotkeyLabel(action)

                love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
                love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 0, 0)

                local progress, barColor, isOverheated, isBlinking = calculateSlotStatus(entry, turretComp)

                if progress > 0 and not isOverheated then
                    local pad = 2 * scaleX
                    local innerX = slotX + pad
                    local innerY = slotY + pad
                    local innerW = slotWidth - pad * 2
                    local innerH = slotHeight - pad * 2 - (12 * scaleY)

                    love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 0, 0)

                    local fillH = math.max(2, (innerH - 2) * math.min(progress, 1.0))
                    local fillX = innerX + 1
                    local fillY = innerY + (innerH - fillH) - 1

                    love.graphics.setColor(barColor)
                    love.graphics.rectangle("fill", fillX, fillY, innerW - 2, fillH, 0, 0)

                    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", innerX, innerY, innerW, innerH, 0, 0)
                    love.graphics.setLineWidth(1)
                end

                if isOverheated then
                    local pad = 2 * scaleX
                    local innerX = slotX + pad
                    local innerY = slotY + pad
                    local innerW = slotWidth - pad * 2
                    local innerH = slotHeight - pad * 2 - (12 * scaleY)

                    love.graphics.setColor(0.05, 0.05, 0.05, 0.9)
                    love.graphics.rectangle("fill", innerX, innerY, innerW, innerH, 0, 0)

                    local remaining = math.max(0, 1 - math.min(progress, 1.0))
                    local fillH = math.max(2, (innerH - 2) * remaining)
                    local fillX = innerX + 1
                    local fillY = innerY + (innerH - fillH) - 1

                    local alpha = isBlinking and 0.7 or 1.0
                    love.graphics.setColor(1.0, 0.2, 0.1, alpha)
                    love.graphics.rectangle("fill", fillX, fillY, innerW - 2, fillH, 0, 0)

                    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", innerX, innerY, innerW, innerH, 0, 0)
                    love.graphics.setLineWidth(1)
                end

                drawModuleIcon(entry, slotX, slotY, slotWidth, slotHeight - (12 * scaleY), scaleU)

                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 0, 0)

                love.graphics.setColor(1, 1, 1, 0.9)
                local labelY = slotY + slotHeight - (12 * scaleY)
                love.graphics.printf(hotkeyLabel, slotX, labelY, slotWidth, "center")
            end
        end)
        lastFrameTick = frameTick
    end

    if hudSystem then
        hudSystem.hoveredHotbarSlot = nil
    end

    if hotbarCanvas then
        BatchRenderer.queueCanvas(hotbarCanvas, drawX, drawY, 1, 1, 1, 1, "overlay")
    end

    local mouseX, mouseY = love.mouse.getPosition()
    for slotIndex = 1, MAX_SLOTS do
        local slotX = drawX + (slotIndex - 1) * (slotWidth + slotSpacing)
        local slotY = drawY
        local entry = entries[slotIndex]
        if entry and mouseX >= slotX and mouseX < slotX + slotWidth and mouseY >= slotY and mouseY < slotY + slotHeight then
            if hudSystem then
                hudSystem.hoveredHotbarSlot = {
                    itemId = entry.itemId,
                    itemDef = entry.itemDef,
                    count = 1,
                    mouseX = mouseX,
                    mouseY = mouseY
                }
            end

            love.graphics.setColor(1.0, 1.0, 1.0, 0.4)
            love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 0, 0)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 0, 0)
            love.graphics.setLineWidth(1)
            break
        end
    end
end

return HUDHotbar
