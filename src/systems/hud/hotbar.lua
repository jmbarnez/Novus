---@diagnostic disable: undefined-global
-- HUD Hotbar Module - renders equipped modules with associated hotkeys and supports drag reordering

local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local ItemDefs = require('src.items.item_loader')
local HotkeyConfig = require('src.hotkey_config')
local TurretRange = require('src.systems.turret_range')
local BatchRenderer = require('src.ui.batch_renderer')
local Theme = require('src.ui.theme')

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
local hotkeyFont = nil

local layoutByDrone = {}
local slotRects = {}
local currentEntries = {}
local currentLayout = nil
local currentDroneId = nil
local dragState = nil

local function getHotkeyLabel(action)
    local key = HotkeyConfig.getHotkey(action)
    if not key or key == "" then
        return "-"
    end
    return HotkeyConfig.formatKey(key)
end

local function getEntryKey(entry)
    local itemId = entry.itemId or ""
    local moduleName = (entry.itemDef and entry.itemDef.module and entry.itemDef.module.name) or ""
    local sourceType = entry.sourceType or "unknown"
    local sourceSlot = entry.sourceSlot or 0
    return string.format("%s:%s:%s:%s", sourceType, tostring(sourceSlot), moduleName, itemId)
end

local function collectEquippedModules(droneId)
    local entries = {}

    local function push(itemId, sourceType, sourceSlot)
        if not itemId then
            return
        end
        local itemDef = ItemDefs[itemId]
        if not itemDef then
            return
        end
        local entry = {
            itemId = itemId,
            itemDef = itemDef,
            sourceType = sourceType,
            sourceSlot = sourceSlot
        }
        entry.key = getEntryKey(entry)
        entries[#entries + 1] = entry
    end

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    if turretSlots and turretSlots.slots then
        for slotIndex = 1, (turretSlots.maxSlots or #turretSlots.slots) do
            push(turretSlots.slots[slotIndex], "turret", slotIndex)
        end
    end

    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    if defensiveSlots and defensiveSlots.slots then
        for slotIndex = 1, (defensiveSlots.maxSlots or #defensiveSlots.slots) do
            push(defensiveSlots.slots[slotIndex], "defensive", slotIndex)
        end
    end

    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
    if generatorSlots and generatorSlots.slots then
        for slotIndex = 1, (generatorSlots.maxSlots or #generatorSlots.slots) do
            push(generatorSlots.slots[slotIndex], "generator", slotIndex)
        end
    end

    return entries
end

local function applyLayout(droneId, rawEntries)
    local layout = layoutByDrone[droneId]
    if not layout then
        layout = {}
        layoutByDrone[droneId] = layout
    end

    local keyToEntry = {}
    for _, entry in ipairs(rawEntries) do
        keyToEntry[entry.key] = entry
    end

    for slot = 1, MAX_SLOTS do
        local key = layout[slot]
        if key and not keyToEntry[key] then
            layout[slot] = nil
        end
    end

    for _, entry in ipairs(rawEntries) do
        local key = entry.key
        local found = false
        for slot = 1, MAX_SLOTS do
            if layout[slot] == key then
                found = true
                break
            end
        end
        if not found then
            local placed = false
            for slot = 1, MAX_SLOTS do
                if layout[slot] == nil then
                    layout[slot] = key
                    placed = true
                    break
                end
            end
            if not placed and #layout < MAX_SLOTS then
                layout[#layout + 1] = key
            end
        end
    end

    while #layout > MAX_SLOTS do
        layout[#layout] = nil
    end

    local ordered = {}
    for slot = 1, MAX_SLOTS do
        local key = layout[slot]
        ordered[slot] = key and keyToEntry[key] or nil
    end

    return ordered, layout
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

local function ensureFont()
    if not hotkeyFont then
        hotkeyFont = Theme.getFont(Theme.fonts.tiny)
    end
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

local function getSlotAtPosition(x, y)
    for index, rect in ipairs(slotRects) do
        if rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            return index
        end
    end
    return nil
end

local function invalidateCanvas()
    lastFrameTick = nil
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
    ensureFont()

    local drawX = (Scaling.getCurrentWidth() - canvasWidth) / 2
    local drawY = Scaling.getCurrentHeight() - canvasHeight - 20

    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local orderedEntries = {}
    local turretComp = nil
    local layout = nil
    local droneId = nil

    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            droneId = input.targetEntity
            local rawEntries = collectEquippedModules(droneId)
            orderedEntries, layout = applyLayout(droneId, rawEntries)
            turretComp = ECS.getComponent(droneId, "Turret")
        end
    end

    if not droneId then
        orderedEntries = {}
        layout = nil
        currentDroneId = nil
        dragState = nil
    else
        currentDroneId = droneId
    end

    currentEntries = orderedEntries
    currentLayout = layout
    slotRects = {}

    if dragState and dragState.droneId ~= currentDroneId then
        dragState = nil
    end

    if shouldUpdate and hotbarCanvas then
        hotbarCanvas:renderTo(function()
            love.graphics.clear(0, 0, 0, 0)
            local previousFont = love.graphics.getFont()
            love.graphics.setFont(hotkeyFont)

            for slotIndex = 1, MAX_SLOTS do
                local slotX = (slotIndex - 1) * (slotWidth + slotSpacing)
                local slotY = 0
                local statusEntry = orderedEntries[slotIndex]
                local iconEntry = statusEntry
                if dragState and dragState.droneId == currentDroneId and dragState.sourceSlot == slotIndex then
                    iconEntry = nil
                end
                local action = SLOT_ACTIONS[slotIndex]
                local hotkeyLabel = getHotkeyLabel(action)

                love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
                love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 0, 0)

                local progress, barColor, isOverheated, isBlinking = calculateSlotStatus(statusEntry, turretComp)

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

                if iconEntry then
                    drawModuleIcon(iconEntry, slotX, slotY, slotWidth, slotHeight - (12 * scaleY), scaleU)
                end

                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 0, 0)

                love.graphics.setColor(1, 1, 1, 0.9)
                local labelY = slotY + slotHeight - (12 * scaleY)
                love.graphics.printf(hotkeyLabel, slotX, labelY, slotWidth, "center")
            end
            love.graphics.setFont(previousFont)
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
        slotRects[slotIndex] = {
            x = slotX,
            y = slotY,
            w = slotWidth,
            h = slotHeight
        }
    end

    for slotIndex = 1, MAX_SLOTS do
        local rect = slotRects[slotIndex]
        local entry = orderedEntries[slotIndex]
        if rect and entry and mouseX >= rect.x and mouseX < rect.x + rect.w and mouseY >= rect.y and mouseY < rect.y + rect.h then
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
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 0, 0)

            love.graphics.setColor(1.0, 1.0, 1.0, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 0, 0)
            love.graphics.setLineWidth(1)

            break
        end
    end

    if dragState and dragState.entry and dragState.droneId == currentDroneId then
        local targetSlot = dragState.targetSlot
        if targetSlot and slotRects[targetSlot] then
            local rect = slotRects[targetSlot]
            love.graphics.setColor(1.0, 1.0, 1.0, 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 0, 0)
            love.graphics.setLineWidth(1)
        end

        local iconSlotHeight = slotHeight - (12 * scaleY)
        local drawXPos = dragState.mouseX - dragState.offsetX
        local drawYPos = dragState.mouseY - dragState.offsetY
        love.graphics.setColor(1, 1, 1, 0.9)
        drawModuleIcon(dragState.entry, drawXPos, drawYPos, slotWidth, iconSlotHeight, scaleU)
    end
end

function HUDHotbar.mousepressed(x, y, button)
    if button ~= 1 or not currentDroneId then
        return false
    end

    local slotIndex = getSlotAtPosition(x, y)
    local entry = slotIndex and currentEntries[slotIndex] or nil
    if slotIndex and entry then
        local rect = slotRects[slotIndex]
        if not rect then
            return false
        end
        dragState = {
            droneId = currentDroneId,
            sourceSlot = slotIndex,
            key = currentLayout and currentLayout[slotIndex],
            entry = entry,
            offsetX = x - rect.x,
            offsetY = y - rect.y,
            mouseX = x,
            mouseY = y,
            targetSlot = slotIndex
        }
        return true
    end

    return false
end

function HUDHotbar.mousemoved(x, y, dx, dy, isTouch)
    if dragState then
        dragState.mouseX = x
        dragState.mouseY = y
        dragState.targetSlot = getSlotAtPosition(x, y)
    end
end

function HUDHotbar.mousereleased(x, y, button)
    if not dragState then
        return false
    end

    local droneId = dragState.droneId
    local sourceSlot = dragState.sourceSlot
    local layout = droneId and layoutByDrone[droneId] or nil

    local targetSlot = dragState.targetSlot or getSlotAtPosition(x, y)
    local moved = false

    if button == 1 and layout and sourceSlot and targetSlot and sourceSlot ~= targetSlot then
        layout[sourceSlot], layout[targetSlot] = layout[targetSlot], layout[sourceSlot]
        moved = true
    end

    dragState = nil

    if droneId then
        local rawEntries = collectEquippedModules(droneId)
        local ordered, updatedLayout = applyLayout(droneId, rawEntries)
        currentEntries = ordered
        currentLayout = updatedLayout
        if moved then
            invalidateCanvas()
        end
    end

    return true
end

HUDHotbar.MAX_SLOTS = MAX_SLOTS
HUDHotbar.actions = SLOT_ACTIONS

function HUDHotbar.getEntriesForDrone(droneId)
    if not droneId then
        return {}
    end
    local rawEntries = collectEquippedModules(droneId)
    local ordered = applyLayout(droneId, rawEntries)
    return ordered
end

function HUDHotbar.getSlotForModule(droneId, moduleName)
    if not droneId or not moduleName then
        return nil
    end
    local entries = HUDHotbar.getEntriesForDrone(droneId)
    for slot, entry in ipairs(entries) do
        if entry and entry.itemDef and entry.itemDef.module and entry.itemDef.module.name == moduleName then
            return slot
        end
    end
    return nil
end

function HUDHotbar.getKeyForSlot(slotIndex)
    local action = SLOT_ACTIONS[slotIndex]
    return action and HotkeyConfig.getHotkey(action) or nil
end

return HUDHotbar
