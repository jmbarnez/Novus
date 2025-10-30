---@diagnostic disable: undefined-global
local Theme = require('src.ui.plasma_theme')
local ECS = require('src.ecs')
local TurretRegistry = require('src.turret_registry')
local Scaling = require('src.scaling')
local StatsWindow = require('src.ui.stats_window')
local DragState = require('src.ui.drag_state')

local LoadoutPanel = {}
LoadoutPanel.MAX_SUBSLOTS_PER_MODULE = 3

local function resolveModuleSubslotCount(itemDef)
    if not itemDef or not itemDef.module then return 0 end

    local module = itemDef.module

    if type(module.subslotCount) == "number" then
        return module.subslotCount
    end
    if type(module.subSlotCount) == "number" then
        return module.subSlotCount
    end
    if type(module.subSlots) == "table" then
        return #module.subSlots
    end
    if type(module.subslots) == "table" then
        return #module.subslots
    end
    if type(module.maxSubslots) == "number" then
        return module.maxSubslots
    end
    if type(module.maxSubSlots) == "number" then
        return module.maxSubSlots
    end

    return 0
end

local function getMousePositionUI()
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        return Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    end
    return Scaling.toUI(love.mouse.getPosition())
end

function LoadoutPanel.draw(shipWin, windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 8
    local contentWidth = width - 20

    shipWin.hoveredItemSlot = nil
    shipWin.hoveredEquipmentSlot = nil

    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

    local leftPanelWidth = contentWidth
    local slotSize = Theme.spacing.slotSize

    local buttonWidth = 180
    local buttonHeight = 34
    local buttonX = contentX + leftPanelWidth - buttonWidth - 10
    local buttonY = contentY
    local mx, my = getMousePositionUI()
    local isHovered = mx and my and mx >= buttonX and mx <= buttonX + buttonWidth and my >= buttonY and my <= buttonY + buttonHeight
    local isPressed = shipWin._statsButtonDown and isHovered

    shipWin._statsButtonRect = {x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight}

    local buttonColor = {0.1, 0.4, 0.55, alpha * 0.9}
    local buttonHoverColor = {0.2, 0.55, 0.75, alpha}
    local buttonActiveColor = {0.15, 0.5, 0.7, alpha}

    if StatsWindow:getOpen() then
        buttonColor = {0.15, 0.55, 0.35, alpha * 0.9}
        buttonHoverColor = {0.25, 0.7, 0.5, alpha}
        buttonActiveColor = {0.2, 0.6, 0.4, alpha}
    end

    local drawColor = buttonColor
    if isPressed then
        drawColor = buttonActiveColor
    elseif isHovered then
        drawColor = buttonHoverColor
    end

    love.graphics.setColor(drawColor)
    love.graphics.rectangle('fill', buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setLineWidth(1)

    local buttonLabel = StatsWindow:getOpen() and "Close Stats" or "Open Stats"
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf(buttonLabel, buttonX, buttonY + 8, buttonWidth, 'center')

    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
    love.graphics.printf("Ship Loadout", contentX + 10, contentY, leftPanelWidth - buttonWidth - 40, 'left')

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.8)
    love.graphics.printf("Detailed statistics are available in the stats window.", contentX + 10, contentY + 26, leftPanelWidth - buttonWidth - 40, 'left')

    local equipmentY = contentY + buttonHeight + 24

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("TURRET", contentX + 10, equipmentY, leftPanelWidth - 20, 'left')
    LoadoutPanel.drawEquipmentSlot(shipWin, "Turret Module", turretSlots and turretSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, equipmentY + 18, slotSize, alpha, droneId)

    local defenseY = equipmentY + slotSize + 36
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("DEFENSE", contentX + 10, defenseY, leftPanelWidth - 20, 'left')
    LoadoutPanel.drawEquipmentSlot(shipWin, "Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, defenseY + 18, slotSize, alpha, droneId)

    local generatorY = defenseY + slotSize + 36
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("GENERATOR", contentX + 10, generatorY, leftPanelWidth - 20, 'left')
    LoadoutPanel.drawEquipmentSlot(shipWin, "Generator Module", generatorSlots and generatorSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, generatorY + 18, slotSize, alpha, droneId)

    if DragState.hasDrag() then
        local draggedItem = DragState.getDragItem()
        if draggedItem and draggedItem.itemDef then
            local mx, my = getMousePositionUI()
            love.graphics.setColor(1, 1, 1, 0.8 * alpha)
            local itemDef = draggedItem.itemDef
            love.graphics.push()
            love.graphics.translate(mx, my)
            love.graphics.scale(1.2, 1.2)
            if itemDef.module and itemDef.module.draw then
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                itemDef:draw(0, 0)
            else
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.8 * alpha)
                love.graphics.circle('fill', 0, 0, 10)
            end
            love.graphics.pop()
        end
    end
end

function LoadoutPanel.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
    local slotSize = width
    local mx, my = getMousePositionUI()
    shipWin.moduleSubslots = shipWin.moduleSubslots or {}

    local isDropZone = false
    if DragState.hasDrag() then
        local draggedItem = DragState.getDragItem()
        if draggedItem and draggedItem.itemDef then
            local itemDef = draggedItem.itemDef
            if (slotName == "Turret Module" and itemDef.type == "turret") or
               (slotName == "Defensive Module" and string.match(draggedItem.itemId, "shield")) or
               (slotName == "Generator Module" and itemDef.type == "generator") then
                if mx >= x and mx <= x + width and my >= y and my <= y + slotSize then
                    isDropZone = true
                end
            end
        end
    end

    local isHoveringSlot = mx >= x and mx <= x + width and my >= y and my <= y + slotSize
    if isHoveringSlot and equippedItemId then
        shipWin.hoveredEquipmentSlot = {
            slotName = slotName,
            itemId = equippedItemId,
            x = x,
            y = y,
            w = width,
            h = slotSize
        }
    end

    if isDropZone then
        love.graphics.setColor(0.3, 0.8, 0.3, alpha * 0.5)
    else
        love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], alpha * 0.8)
    end
    love.graphics.rectangle('fill', x, y, slotSize, slotSize, 4, 4)

    local borderColor = isDropZone and {0.3, 1, 0.3, alpha} or {Theme.colors.borderAlt[1], Theme.colors.borderAlt[2], Theme.colors.borderAlt[3], alpha}
    love.graphics.setColor(borderColor)
    love.graphics.rectangle('line', x, y, slotSize, slotSize, 4, 4)

    shipWin.equipmentSlots = shipWin.equipmentSlots or {}
    shipWin.equipmentSlots[slotName] = {x = x, y = y, w = slotSize, h = slotSize, slotType = slotName, itemId = equippedItemId}

    local itemDef
    if equippedItemId then
        local ItemDefs = require('src.items.item_loader')
        itemDef = ItemDefs[equippedItemId]
    end

    if itemDef then
        if isHoveringSlot then
            local color = (itemDef.module and itemDef.module.design and itemDef.module.design.color) or (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.3 * alpha)
            love.graphics.rectangle('fill', x, y, slotSize, slotSize, 4, 4)
        end
        local iconSize = slotSize * 0.8
        local iconX = x + (slotSize - iconSize) / 2
        local iconY = y + (slotSize - iconSize) / 2
        love.graphics.push()
        love.graphics.translate(iconX + iconSize/2, iconY + iconSize/2)
        love.graphics.scale(iconSize/48, iconSize/48)
        if itemDef.module and itemDef.module.draw then
            love.graphics.setColor(1, 1, 1, alpha)
            itemDef.module.draw(itemDef.module, 0, 0)
        elseif itemDef.draw then
            itemDef:draw(0, 0)
        else
            local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.circle('fill', 0, 0, iconSize / 4)
        end
        love.graphics.pop()
    end

    local activeSubslots = resolveModuleSubslotCount(itemDef)
    LoadoutPanel.drawModuleSubslots(shipWin, slotName, x, y, slotSize, alpha, activeSubslots, LoadoutPanel.MAX_SUBSLOTS_PER_MODULE)

    -- Redraw the main slot border on top so it's always visible when subslots are drawn
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 1)
    love.graphics.setLineWidth(math.max(2, math.floor(slotSize * 0.08)))
    love.graphics.rectangle('line', x, y, slotSize, slotSize, 6, 6)
    love.graphics.setLineWidth(1)
end

function LoadoutPanel.unequipModule(shipWin, slotType, itemId)
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local cargo = ECS.getComponent(droneId, "Cargo")

    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        local playerTurret = ECS.getComponent(droneId, "Turret")

        if turretSlots and turretSlots.slots[1] == itemId and cargo then
            turretSlots.slots[1] = nil
            if playerTurret then
                playerTurret.moduleName = nil
            end
            cargo:addItem(itemId, 1)
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots and defensiveSlots.slots[1] == itemId and cargo then
            defensiveSlots.slots[1] = nil
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            cargo:addItem(itemId, 1)
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

        if generatorSlots and generatorSlots.slots[1] == itemId and cargo then
            generatorSlots.slots[1] = nil
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            cargo:addItem(itemId, 1)
        end
    end
end

function LoadoutPanel.equipModule(shipWin, itemId)
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return false end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return false end
    local droneId = input.targetEntity

    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo or not cargo.items[itemId] or cargo.items[itemId] <= 0 then return false end

    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return false end

    if itemDef.type == "turret" then
        -- Check level requirement
        local module = itemDef.module
        if module and module.levelRequirement then
            local LevelUtils = require('src.level_utils')
            local playerLevelData = LevelUtils.getPlayerLevelData()
            local playerLevel = playerLevelData and playerLevelData.level or 1
            
            if playerLevel < module.levelRequirement then
                local Notifications = require('src.ui.notifications')
                local moduleName = module.displayName or itemDef.name or itemId
                local message = string.format("%s requires level %d (you are level %d)", moduleName, module.levelRequirement, playerLevel)
                Notifications.addNotification({
                    type = 'system',
                    text = message,
                    timer = 4.0
                })
                return false -- Prevent equipping
            end
        end
        
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        local playerTurret = ECS.getComponent(droneId, "Turret")

        if turretSlots and playerTurret then
            local oldModuleId = turretSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
            end
            turretSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.name then
                playerTurret.moduleName = itemDef.module.name
                if not TurretRegistry.hasModule(playerTurret.moduleName) then
                    TurretRegistry.registerModule(playerTurret.moduleName, itemDef.module)
                end
            end
            cargo:removeItem(itemId, 1)
            return true -- Successfully equipped
        end
        return false
    elseif itemDef.type == "shield" or string.match(itemId, "shield") then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots then
            local oldModuleId = defensiveSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
            end
            defensiveSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
            return true -- Successfully equipped
        end
        return false
    elseif itemDef.type == "generator" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

        if generatorSlots then
            local oldModuleId = generatorSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
            end
            generatorSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
            return true -- Successfully equipped
        end
        return false
    end
    return false
end

function LoadoutPanel.mousepressed(shipWin, x, y, button)
    if button == 1 then
        if shipWin._statsButtonRect then
            local rect = shipWin._statsButtonRect
            if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                shipWin._statsButtonDown = true
                return
            end
        end

        if shipWin.hoveredItemSlot then
            DragState.startDrag({
                itemId = shipWin.hoveredItemSlot.itemId,
                itemDef = shipWin.hoveredItemSlot.itemDef,
                slotIndex = shipWin.hoveredItemSlot.slotIndex,
                count = shipWin.hoveredItemSlot.count,
                fromCargo = false,
                fromEquipment = false
            })
        elseif shipWin.hoveredEquipmentSlot then
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[shipWin.hoveredEquipmentSlot.itemId]
            if itemDef then
                DragState.startDrag({
                    itemId = shipWin.hoveredEquipmentSlot.itemId,
                    itemDef = itemDef,
                    slotName = shipWin.hoveredEquipmentSlot.slotName,
                    fromCargo = false,
                    fromEquipment = true
                })
            end
        end
    elseif button == 2 then
        if shipWin.hoveredEquipmentSlot then
            LoadoutPanel.unequipModule(shipWin, shipWin.hoveredEquipmentSlot.slotName, shipWin.hoveredEquipmentSlot.itemId)
        end
    end
end

function LoadoutPanel.mousereleased(shipWin, x, y, button)
    local handledStatsClick = false
    if shipWin._statsButtonDown then
        shipWin._statsButtonDown = false
        if button == 1 and shipWin._statsButtonRect then
            local rect = shipWin._statsButtonRect
            if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                local shouldOpen = not StatsWindow:getOpen()
                StatsWindow:setOpen(shouldOpen)
                if shouldOpen then
                    local UISystem = require('src.systems.ui')
                    if UISystem and UISystem.setWindowFocus then
                        UISystem.setWindowFocus('stats_window')
                    end
                end
                handledStatsClick = true
            end
        end
    end

    if handledStatsClick then
        return
    end

    if button == 1 and DragState.hasDrag() then
        local draggedItem = DragState.getDragItem()
        if not draggedItem then
            DragState.endDrag()
            return
        end

        local controllers = ECS.getEntitiesWith({'InputControlled', 'Player'})
        if #controllers == 0 then
            DragState.endDrag()
            return
        end

        local pilotId = controllers[1]
        local inputComp = ECS.getComponent(pilotId, 'InputControlled')
        local shipId = inputComp and inputComp.targetEntity or nil
        if not shipId then
            DragState.endDrag()
            return
        end

        local cargo = ECS.getComponent(shipId, 'Cargo')
        if not cargo then
            DragState.endDrag()
            return
        end

        local equippedToSlot = false
        if shipWin.equipmentSlots then
            for slotName, slotRect in pairs(shipWin.equipmentSlots) do
                if x >= slotRect.x and x <= slotRect.x + slotRect.w and
                   y >= slotRect.y and y <= slotRect.y + slotRect.h then
                    local itemDef = draggedItem.itemDef
                    if (slotName == 'Turret Module' and itemDef.type == 'turret') or
                       (slotName == 'Defensive Module' and string.match(draggedItem.itemId, 'shield')) or
                       (slotName == 'Generator Module' and itemDef.type == 'generator') then
                        if draggedItem.fromEquipment and draggedItem.slotName then
                            LoadoutPanel.unequipModule(shipWin, draggedItem.slotName, draggedItem.itemId)
                        end
                        local success = LoadoutPanel.equipModule(shipWin, draggedItem.itemId)
                        if success then
                            equippedToSlot = true
                        end
                        break
                    end
                end
            end
        end

        -- Handle dropping sub-modules onto active subslots of the Turret Module
        if not equippedToSlot and shipWin.moduleSubslots and draggedItem and draggedItem.itemDef and draggedItem.itemDef.type == 'submodule' then
            local turretSlot = shipWin.moduleSubslots['Turret Module']
            if turretSlot then
                for idx, rect in pairs(turretSlot) do
                    if rect.enabled and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                        -- Equip sub-module if compatible and capacity allows
                        local ItemDefs = require('src.items.item_loader')
                        local turretSlots = ECS.getComponent(shipId, 'TurretSlots')
                        local playerTurret = ECS.getComponent(shipId, 'Turret')
                        local equippedTurretId = turretSlots and turretSlots.slots and turretSlots.slots[1] or nil
                        local turretItem = equippedTurretId and ItemDefs[equippedTurretId] or nil
                        local activeCount = turretItem and resolveModuleSubslotCount(turretItem) or 0
                        if playerTurret then
                            local currentCount = (playerTurret.subModules and #playerTurret.subModules) or 0
                            if currentCount < activeCount then
                                local subItem = draggedItem.itemDef
                                local compat = subItem.submodule and subItem.submodule.compatible or subItem.compatible or {}
                                local ok = false
                                if compat and (compat.moduleType == nil or compat.moduleType == 'turret') then
                                    local turretMod = turretItem and turretItem.module or nil
                                    if compat.skill == nil then
                                        ok = true
                                    else
                                        local skill = turretMod and turretMod.skill or nil
                                        ok = (skill == compat.skill)
                                    end
                                end
                                if ok then
                                    playerTurret.subModules = playerTurret.subModules or {}
                                    table.insert(playerTurret.subModules, subItem.submodule or subItem)
                                    -- consume from cargo
                                    local itemId = draggedItem.itemId
                                    if cargo and cargo.items and cargo.items[itemId] and cargo.items[itemId] > 0 then
                                        cargo.items[itemId] = cargo.items[itemId] - 1
                                        if cargo.items[itemId] <= 0 then cargo.items[itemId] = nil end
                                    end
                                    equippedToSlot = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        if not equippedToSlot then
            -- Check if dropped on cargo window (cross-window drag)
            local CargoWindow = require('src.ui.cargo_window')
            local cargoWindow = CargoWindow
            local cargoOpen = cargoWindow:getOpen()
            local isInCargoWindow = false
            if cargoOpen then
                local cargoX, cargoY = cargoWindow.position.x, cargoWindow.position.y
                local cargoW, cargoH = cargoWindow.width, cargoWindow.height
                isInCargoWindow = x >= cargoX and x <= cargoX + cargoW and y >= cargoY and y <= cargoY + cargoH
            end

            local windowX, windowY = shipWin.position.x, shipWin.position.y
            local windowW, windowH = shipWin.width, shipWin.height
            local isOutsideLoadoutWindow = x < windowX or x > windowX + windowW or y < windowY or y > windowY + windowH

            if draggedItem.fromEquipment then
                -- If dropped on cargo window, unequip and add to cargo
                if isInCargoWindow then
                    if draggedItem.slotName then
                        LoadoutPanel.unequipModule(shipWin, draggedItem.slotName, draggedItem.itemId)
                        cargo:addItem(draggedItem.itemId, 1)
                    end
                elseif not isOutsideLoadoutWindow then
                    -- Dropped back in loadout window, just unequip
                    if draggedItem.slotName then
                        LoadoutPanel.unequipModule(shipWin, draggedItem.slotName, draggedItem.itemId)
                    end
                else
                    -- Dropped outside both windows, unequip and discard
                    if draggedItem.slotName then
                        LoadoutPanel.unequipModule(shipWin, draggedItem.slotName, draggedItem.itemId)
                    end
                end
            elseif draggedItem.fromCargo then
                -- If dropped outside loadout window and not on cargo window, discard from cargo
                if isOutsideLoadoutWindow and not isInCargoWindow then
                    local itemId = draggedItem.itemId
                    if cargo.items[itemId] and cargo.items[itemId] > 0 then
                        cargo.items[itemId] = cargo.items[itemId] - 1
                        if cargo.items[itemId] <= 0 then
                            cargo.items[itemId] = nil
                        end
                    end
                end
            end
        end

        DragState.endDrag()
    end
end

function LoadoutPanel.mousemoved(shipWin, x, y, dx, dy)
    -- No special handling needed beyond hover detection in draw
end

function LoadoutPanel.drawModuleSubslots(shipWin, slotName, slotX, slotY, slotSize, alpha, activeCount, totalCount)
    totalCount = totalCount or LoadoutPanel.MAX_SUBSLOTS_PER_MODULE or 0
    if totalCount <= 0 then return end

    activeCount = math.max(0, math.min(activeCount or 0, totalCount))

    -- Draw subslots as full-size slots lined up horizontally on the same line as the main slot
    local spacing = math.max(6, math.floor(slotSize * 0.12))
    local dashGap = math.max(8, math.floor(slotSize * 0.2))
    local subslotSize = slotSize

    local totalWidth = subslotSize * totalCount + spacing * (totalCount - 1)
    local startX = slotX + slotSize + dashGap
    local startY = slotY

    -- Draw a simple dash (short line) between main slot and first subslot area
    local dashStart = slotX + slotSize + math.floor(dashGap * 0.2)
    local dashEnd = slotX + slotSize + math.floor(dashGap * 0.8)
    local centerY = slotY + slotSize / 2
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
    love.graphics.setLineWidth(math.max(2, math.floor(slotSize * 0.06)))
    love.graphics.line(dashStart, centerY, dashEnd, centerY)
    love.graphics.setLineWidth(1)

    shipWin.moduleSubslots[slotName] = {}

    local enabledColor = Theme.colors.hover
    local disabledFill = Theme.colors.surfaceAlt
    local disabledBorder = Theme.colors.border
    local activeBorder = Theme.colors.borderLight
    local crossColor = Theme.colors.textMuted

    for index = 1, totalCount do
        local sx = startX + (index - 1) * (subslotSize + spacing)
        local sy = startY
        local isActive = index <= activeCount

        if isActive then
            love.graphics.setColor(enabledColor[1], enabledColor[2], enabledColor[3], (enabledColor[4] or 1) * alpha * 0.55)
        else
            love.graphics.setColor(disabledFill[1], disabledFill[2], disabledFill[3], (disabledFill[4] or 1) * alpha * 0.6)
        end
        love.graphics.rectangle('fill', sx, sy, subslotSize, subslotSize, 4, 4)

        local borderColor = isActive and activeBorder or disabledBorder
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
        love.graphics.rectangle('line', sx, sy, subslotSize, subslotSize, 4, 4)

        if not isActive then
            love.graphics.setColor(crossColor[1], crossColor[2], crossColor[3], (crossColor[4] or 1) * alpha * 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.line(sx + 4, sy + 4, sx + subslotSize - 4, sy + subslotSize - 4)
            love.graphics.line(sx + 4, sy + subslotSize - 4, sx + subslotSize - 4, sy + 4)
            love.graphics.setLineWidth(1)
        end

        shipWin.moduleSubslots[slotName][index] = {
            x = sx,
            y = sy,
            w = subslotSize,
            h = subslotSize,
            enabled = isActive
        }
    end
end

return LoadoutPanel
