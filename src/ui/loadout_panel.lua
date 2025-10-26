---@diagnostic disable: undefined-global
local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local TurretRegistry = require('src.turret_registry')
local Scaling = require('src.scaling')

local LoadoutPanel = {}

function LoadoutPanel.draw(shipWin, windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 40 + 10
    local contentWidth = shipWin.width - 20
    local contentHeight = shipWin.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 40 - 20

    -- Reset hovered items
    shipWin.hoveredItemSlot = nil
    shipWin.hoveredEquipmentSlot = nil

    -- Get ship equipment and cargo
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
    local cargo = ECS.getComponent(droneId, "Cargo")
    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")

    -- Use the full content area for stats + equipment (no right-side cargo in this tab)
    local leftPanelWidth = contentWidth

    -- LEFT PANEL: Ship Stats and Equipment
    local slotSize = Theme.spacing.slotSize

    -- Basic stats summary (much simpler now)
    local Constants = require('src.constants')
    local physics = ECS.getComponent(droneId, "Physics")
    local mass = physics and physics.mass or 1
    local baseMaxVelocity = Constants.player_max_speed
    local maxVelocity = baseMaxVelocity / mass
    local totalEffectiveHP = (hull and hull.max or 0) + (shield and shield.max or 0)

    local turret = ECS.getComponent(droneId, "Turret")
    local turretDPS = 0
    if turret and turret.moduleName and turret.moduleName ~= "" then
        local TurretRegistry = require('src.turret_registry')
        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule then
            turretDPS = turretModule.DPS or 0
        end
    end

    -- Simple stats summary box
    local summaryHeight = 60
    local summaryX = contentX + 10
    local summaryY = contentY
    local summaryWidth = leftPanelWidth - 20

    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
    love.graphics.rectangle("fill", summaryX, summaryY, summaryWidth, summaryHeight, 3, 3)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
    love.graphics.rectangle("line", summaryX, summaryY, summaryWidth, summaryHeight, 3, 3)

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.printf("SHIP SUMMARY", summaryX + 5, summaryY + 8, summaryWidth - 10, "left")

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    love.graphics.printf(string.format("HP: %d | DPS: %.0f | Vel: %.0f u/s | Mass: %.1f", totalEffectiveHP, turretDPS, maxVelocity, mass), 
                        summaryX + 8, summaryY + 26, summaryWidth - 16, "left")

    local equipmentY = contentY + summaryHeight + 20
    -- Stats button: opens the detailed StatsWindow
    local StatsWindow = require('src.ui.stats_window')
    local statsBtnW, statsBtnH = 90, 28
    local statsBtnX = contentX + 8
    local statsBtnY = equipmentY - statsBtnH - 8
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    local hoveredStats = mx >= statsBtnX and mx <= statsBtnX + statsBtnW and my >= statsBtnY and my <= statsBtnY + statsBtnH
    love.graphics.setColor(hoveredStats and Theme.colors.buttonHover or Theme.colors.bgMedium)
    love.graphics.rectangle('fill', statsBtnX, statsBtnY, statsBtnW, statsBtnH, 5, 5)
    love.graphics.setColor(Theme.colors.borderMedium)
    love.graphics.rectangle('line', statsBtnX, statsBtnY, statsBtnW, statsBtnH, 5, 5)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf('Stats', statsBtnX, statsBtnY + 6, statsBtnW, 'center')

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("TURRET", contentX + 10, equipmentY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Turret Module", turretSlots and turretSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, equipmentY + 12, slotSize, alpha, droneId)

    local defenseY = equipmentY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("DEFENSE", contentX + 10, defenseY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, defenseY + 12, slotSize, alpha, droneId)

    local generatorY = defenseY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("GENERATOR", contentX + 10, generatorY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Generator Module", generatorSlots and generatorSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, generatorY + 12, slotSize, alpha, droneId)

    -- Draw dragged item at mouse position
    if shipWin.draggedItem and shipWin.draggedItem.itemDef then
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
        love.graphics.setColor(1, 1, 1, 0.8 * alpha)
        local itemDef = shipWin.draggedItem.itemDef
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
            love.graphics.circle("fill", 0, 0, 10)
        end
        love.graphics.pop()
    end
end

function LoadoutPanel.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
    local slotSize = width
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
    mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    local isDropZone = false
    if shipWin.draggedItem and shipWin.draggedItem.itemDef then
        local itemDef = shipWin.draggedItem.itemDef
        if (slotName == "Turret Module" and itemDef.type == "turret") or
           (slotName == "Defensive Module" and string.match(shipWin.draggedItem.itemId, "shield")) or
           (slotName == "Generator Module" and itemDef.type == "generator") then
            if mx >= x and mx <= x + width and my >= y and my <= y + slotSize then
                isDropZone = true
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
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
    end
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)

    local borderColor = isDropZone and {0.3, 1, 0.3, alpha} or {Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha}
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, 4, 4)

    shipWin.equipmentSlots = shipWin.equipmentSlots or {}
    shipWin.equipmentSlots[slotName] = {x = x, y = y, w = slotSize, h = slotSize, slotType = slotName, itemId = equippedItemId}

    if equippedItemId then
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            if isHoveringSlot then
                local color = (itemDef.module and itemDef.module.design and itemDef.module.design.color) or (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.3 * alpha)
                love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)
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
                love.graphics.circle("fill", 0, 0, iconSize / 4)
            end
            love.graphics.pop()
        end
    end
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
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo or not cargo.items[itemId] or cargo.items[itemId] <= 0 then return end

    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return end

    if itemDef.type == "turret" then
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
                    playerTurret.moduleName = nil
                end
            else
                playerTurret.moduleName = nil
            end
            cargo:removeItem(itemId, 1)
        end
    elseif string.match(itemId, "shield") then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots then
            local oldModuleId = defensiveSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end
            defensiveSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
        end
    elseif itemDef.type == "generator" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots then
            local oldModuleId = generatorSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end
            generatorSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
        end
    end
end

function LoadoutPanel.mousepressed(shipWin, x, y, button)
    -- Left click: start dragging from cargo or equipment slots
    if button == 1 then
        if shipWin.hoveredItemSlot then
            shipWin.draggedItem = {
                itemId = shipWin.hoveredItemSlot.itemId,
                itemDef = shipWin.hoveredItemSlot.itemDef,
                slotIndex = shipWin.hoveredItemSlot.slotIndex,
                count = shipWin.hoveredItemSlot.count,
                fromEquipment = false
            }
        elseif shipWin.hoveredEquipmentSlot then
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[shipWin.hoveredEquipmentSlot.itemId]
            if itemDef then
                shipWin.draggedItem = {
                    itemId = shipWin.hoveredEquipmentSlot.itemId,
                    itemDef = itemDef,
                    slotName = shipWin.hoveredEquipmentSlot.slotName,
                    fromEquipment = true
                }
            end
        end
        -- Check Stats button click
        local contentX = shipWin.position.x + 10
        local summaryHeight = 60
        local equipmentY = shipWin.position.y + Theme.window.topBarHeight + 40 + 10 + summaryHeight + 20
        local statsBtnW, statsBtnH = 90, 28
        local statsBtnX = contentX + 8
        local statsBtnY = equipmentY - statsBtnH - 8
        if x >= statsBtnX and x <= statsBtnX + statsBtnW and y >= statsBtnY and y <= statsBtnY + statsBtnH then
            local StatsWindow = require('src.ui.stats_window')
            StatsWindow:openCenteredIn(shipWin)
            return
        end
    elseif button == 2 then
        -- Right click: remove from equipment slot
        if shipWin.hoveredEquipmentSlot then
            LoadoutPanel.unequipModule(shipWin, shipWin.hoveredEquipmentSlot.slotName, shipWin.hoveredEquipmentSlot.itemId)
        end
    end
end

function LoadoutPanel.mousereleased(shipWin, x, y, button)
    if button == 1 and shipWin.draggedItem then
        -- Get the player's controlled ship for cargo access
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers == 0 then
            shipWin.draggedItem = nil
            return
        end
        local pilotId = controllers[1]
        local inputComp = ECS.getComponent(pilotId, "InputControlled")
        local shipId = inputComp and inputComp.targetEntity or nil
        if not shipId then
            shipWin.draggedItem = nil
            return
        end

        local cargo = ECS.getComponent(shipId, "Cargo")
        if not cargo then
            shipWin.draggedItem = nil
            return
        end

        -- Check if dropped on an equipment slot
        local equippedToSlot = false
        if shipWin.equipmentSlots then
            for slotName, slotRect in pairs(shipWin.equipmentSlots) do
                if x >= slotRect.x and x <= slotRect.x + slotRect.w and
                   y >= slotRect.y and y <= slotRect.y + slotRect.h then
                    local itemDef = shipWin.draggedItem.itemDef
                    if (slotName == "Turret Module" and itemDef.type == "turret") or
                       (slotName == "Defensive Module" and string.match(shipWin.draggedItem.itemId, "shield")) or
                       (slotName == "Generator Module" and itemDef.type == "generator") then
                        if shipWin.draggedItem.fromEquipment and shipWin.draggedItem.slotName then
                            LoadoutPanel.unequipModule(shipWin, shipWin.draggedItem.slotName, shipWin.draggedItem.itemId)
                        end
                        LoadoutPanel.equipModule(shipWin, shipWin.draggedItem.itemId)
                        equippedToSlot = true
                        break
                    end
                end
            end
        end

        if not equippedToSlot then
            local windowX, windowY = shipWin.position.x, shipWin.position.y
            local windowW, windowH = shipWin.width, shipWin.height
            local isOutsideBounds = x < windowX or x > windowX + windowW or y < windowY or y > windowY + windowH

            if shipWin.draggedItem.fromEquipment then
                if not isOutsideBounds then
                    if shipWin.draggedItem.slotName then
                        LoadoutPanel.unequipModule(shipWin, shipWin.draggedItem.slotName, shipWin.draggedItem.itemId)
                    end
                else
                    if shipWin.draggedItem.slotName then
                        LoadoutPanel.unequipModule(shipWin, shipWin.draggedItem.slotName, shipWin.draggedItem.itemId)
                        local itemId = shipWin.draggedItem.itemId
                        if cargo and cargo.items and cargo.items[itemId] then
                            cargo.items[itemId] = cargo.items[itemId] - 1
                            if cargo.items[itemId] <= 0 then
                                cargo.items[itemId] = nil
                            end
                        end
                    end
                end
            else
                if isOutsideBounds then
                    local itemId = shipWin.draggedItem.itemId
                    if cargo and cargo.items and cargo.items[itemId] then
                        cargo.items[itemId] = cargo.items[itemId] - 1
                        if cargo.items[itemId] <= 0 then
                            cargo.items[itemId] = nil
                        end
                    end
                end
            end
        end

        shipWin.draggedItem = nil
    end
end

function LoadoutPanel.mousemoved(shipWin, x, y, dx, dy)
    -- No-op; ShipWindow handles context menu hover centrally
end

return LoadoutPanel
