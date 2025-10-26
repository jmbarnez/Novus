---@diagnostic disable: undefined-global
local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local Scaling = require('src.scaling')

local CargoPanel = {}

function CargoPanel.draw(shipWin, windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 40 + 10
    local contentWidth = shipWin.width - 20
    local contentHeight = shipWin.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 40 - 20

    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return end

    shipWin.hoveredItemSlot = nil
    -- Draw cargo grid full area
    shipWin:drawCargoGrid(cargo.items, contentX, contentY, contentWidth, contentHeight, alpha)

    if shipWin.contextMenu then
        shipWin:drawContextMenu(shipWin.contextMenu.x, shipWin.contextMenu.y, alpha)
    end
end

function CargoPanel.drawCargoGrid(shipWin, cargoItems, x, y, width, height, alpha)
    local ItemDefs = require('src.items.item_loader')
    local slotSize = Theme.spacing.slotSize
    local padding = Theme.spacing.iconGridPadding
    local cols = math.max(1, math.floor(width / (slotSize + padding)))
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    local i = 0

    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local row = math.floor(i / cols)
            local col = i % cols
            local slotX = x + col * (slotSize + padding)
            local slotY = y + row * (slotSize + padding)

            local isHoveringSlot = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize

            if isHoveringSlot then
                shipWin.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
            end

            local compatibleSlots = CargoPanel.getCompatibleSlots(shipWin, itemId)
            if #compatibleSlots > 0 then
                love.graphics.setColor(0.1, 0.25, 0.1, alpha * 0.4)
                love.graphics.rectangle("fill", slotX - 1, slotY - 1, slotSize + 2, slotSize + 2, 5, 5)
                love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            else
                love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            end
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)

            if isHoveringSlot then
                love.graphics.setColor(Theme.colors.bgLight[1], Theme.colors.bgLight[2], Theme.colors.bgLight[3], 0.32 * alpha)
                love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            end

            if #compatibleSlots > 0 then
                love.graphics.setColor(0.15, 0.35, 0.15, alpha * 0.6)
            else
                love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.3)
            end
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)

            love.graphics.push()
            love.graphics.translate(slotX + slotSize / 2, slotY + slotSize / 2)
            love.graphics.scale(1, 1)
            if type(itemDef.module) == "table" and itemDef.module.draw then
                love.graphics.setColor(1, 1, 1, alpha)
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                itemDef:draw(0, 0)
            else
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                love.graphics.circle("fill", 0, 0, slotSize / 4)
            end
            love.graphics.pop()

            if count > 1 then
                love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
                love.graphics.setFont(Theme.getFont(Theme.fonts.small))
                love.graphics.printf(tostring(count), slotX, slotY + slotSize - 16, slotSize, "center")
            end

            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            local label = (itemDef and itemDef.name) or tostring(itemId)
            love.graphics.printf(label, slotX, slotY + slotSize + 4, slotSize, "center")

            i = i + 1
        end
    end
end

function CargoPanel.canEquipInSlot(shipWin, itemId, slotType)
    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return false end

    if slotType == "Turret Module" then
        return itemDef.type == "turret"
    elseif slotType == "Defensive Module" then
        return string.match(itemId, "shield") or itemDef.type == "shield"
    elseif slotType == "Generator Module" then
        return itemDef.type == "generator"
    end

    return false
end

function CargoPanel.getCompatibleSlots(shipWin, itemId)
    local compatibleSlots = {}
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Turret Module") then
        table.insert(compatibleSlots, "Turret Module")
    end
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Defensive Module") then
        table.insert(compatibleSlots, "Defensive Module")
    end
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Generator Module") then
        table.insert(compatibleSlots, "Generator Module")
    end
    return compatibleSlots
end

function CargoPanel.openContextMenu(shipWin, itemId, itemDef, x, y)
    local compatibleSlots = CargoPanel.getCompatibleSlots(shipWin, itemId)
    local options = {}
    for _, slotType in ipairs(compatibleSlots) do
        table.insert(options, { text = "Equip to " .. slotType, action = "equip", slotType = slotType })
    end
    table.insert(options, { text = "Cancel", action = "cancel" })
    shipWin.contextMenu = { itemId = itemId, itemDef = itemDef, x = x, y = y, options = options, hoveredOption = nil }
end

function CargoPanel.handleContextMenuClick(shipWin, optionIndex)
    if not shipWin.contextMenu or not shipWin.contextMenu.options[optionIndex] then return end
    local option = shipWin.contextMenu.options[optionIndex]
    if option.action == "equip" and option.slotType then
        -- Delegate equipping to LoadoutPanel (which has equipModule)
        local LoadoutPanel = require('src.ui.loadout_panel')
        LoadoutPanel.equipModule(shipWin, shipWin.contextMenu.itemId)
    end
    shipWin.contextMenu = nil
end

function CargoPanel.drawContextMenu(shipWin, x, y, alpha)
    local menuWidth = 200
    local menuHeight = 40 + (#shipWin.contextMenu.options * 25)
    local itemDef = shipWin.contextMenu.itemDef
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.95)
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight, 5, 5)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.rectangle("line", x, y, menuWidth, menuHeight, 5, 5)
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    local itemName = itemDef and itemDef.name or shipWin.contextMenu.itemId
    love.graphics.printf(itemName, x + 8, y + 8, menuWidth - 16, "left")
    local compatibleSlots = CargoPanel.getCompatibleSlots(shipWin, shipWin.contextMenu.itemId)
    if #compatibleSlots > 0 then
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local compatText = "Compatible: " .. table.concat(compatibleSlots, ", ")
        love.graphics.printf(compatText, x + 8, y + 25, menuWidth - 16, "left")
    else
        love.graphics.setColor(Theme.colors.textSecondary[1] * 0.5, Theme.colors.textSecondary[2] * 0.5, Theme.colors.textSecondary[3] * 0.5, alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        love.graphics.printf("No compatible slots", x + 8, y + 25, menuWidth - 16, "left")
    end
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    for i, option in ipairs(shipWin.contextMenu.options) do
        local optionY = y + 40 + (i-1) * 25
        local isHovered = shipWin.contextMenu.hoveredOption == i
        if isHovered then
            love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.8)
            love.graphics.rectangle("fill", x + 5, optionY - 2, menuWidth - 10, 22, 3, 3)
        end
        if option.action == "equip" then
            love.graphics.setColor(0.15, 0.4, 0.15, alpha)
        elseif option.action == "cancel" then
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        else
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        end
        love.graphics.printf(option.text, x + 8, optionY + 2, menuWidth - 16, "left")
    end
end

function CargoPanel.mousepressed(shipWin, x, y, button)
    -- Delegate to ship window logic (maintain existing behavior)
    if button == 2 and shipWin.hoveredItemSlot and not shipWin.contextMenu then
        -- Use UI-space coordinates for context menu positioning
        local uiX, uiY
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiX, uiY = x, y
        end
        shipWin:openContextMenu(shipWin.hoveredItemSlot.itemId, shipWin.hoveredItemSlot.itemDef, uiX, uiY)
    end
end

function CargoPanel.mousereleased(shipWin, x, y, button)
    -- No-op; ship window handles release logic centrally
end

function CargoPanel.mousemoved(shipWin, x, y, dx, dy)
    -- No-op; ship window handles context menu hover centrally
end

return CargoPanel
