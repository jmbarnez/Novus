---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local ContextMenu = require('src.ui.context_menu')
local DragState = require('src.ui.drag_state')
local UIUtils = require('src.ui.ui_utils')
local StatsWindow = require('src.ui.stats_window')

-- Shared helper module for equip/unequip logic
local ModuleEquipHelpers = {}

-- Determine slot type from item definition
function ModuleEquipHelpers.getSlotType(itemDef, itemId)
    if itemDef.type == "turret" then
        return "Turret Module"
    elseif itemDef.type == "shield" or string.match(itemId or "", "shield") then
        return "Defensive Module"
    elseif itemDef.type == "generator" then
        return "Generator Module"
    end
    return nil
end

-- Unequip a module from a slot (calls module.unequip if available)
function ModuleEquipHelpers.unequipModuleFromSlot(droneId, slotType, ItemDefs)
    local ECS = require('src.ecs')
    
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots and turretSlots.slots[1] then
            return turretSlots.slots[1]
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1] then
            local oldItemId = defensiveSlots.slots[1]
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            return oldItemId
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots and generatorSlots.slots[1] then
            local oldItemId = generatorSlots.slots[1]
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            return oldItemId
        end
    end
    return nil
end

-- Equip a module to a slot (calls module.equip if available)
function ModuleEquipHelpers.equipModuleToSlot(droneId, slotType, itemId, itemDef)
    local ECS = require('src.ecs')
    
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if not turretSlots then return false end
        turretSlots.slots[1] = itemId
        local turret = ECS.getComponent(droneId, "Turret")
        if turret then
            turret.moduleName = itemId
        end
        return true
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if not defensiveSlots then return false end
        defensiveSlots.slots[1] = itemId
        if itemDef.module and itemDef.module.equip then
            itemDef.module.equip(droneId)
        end
        return true
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if not generatorSlots then return false end
        generatorSlots.slots[1] = itemId
        if itemDef.module and itemDef.module.equip then
            itemDef.module.equip(droneId)
        end
        return true
    end
    return false
end

-- Main equip function - handles common logic for equipping modules
function ModuleEquipHelpers.equipModule(droneId, itemId)
    local ECS = require('src.ecs')
    local ItemDefs = require('src.items.item_loader')
    
    local itemDef = ItemDefs[itemId]
    if not itemDef then return false end
    
    local slotType = ModuleEquipHelpers.getSlotType(itemDef, itemId)
    if not slotType then return false end
    
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return false end
    
    if not cargo.items[itemId] or cargo.items[itemId] < 1 then
        return false
    end
    
    -- Unequip old module if present
    local oldItemId = ModuleEquipHelpers.unequipModuleFromSlot(droneId, slotType, ItemDefs)
    if oldItemId then
        cargo:addItem(oldItemId, 1)
    end
    
    -- Equip new module
    if not ModuleEquipHelpers.equipModuleToSlot(droneId, slotType, itemId, itemDef) then
        return false
    end
    
    -- Remove item from cargo
    cargo:removeItem(itemId, 1)
    return true
end

-- Unequip module from slot (returns itemId if successful)
function ModuleEquipHelpers.unequipModule(droneId, slotType)
    local ECS = require('src.ecs')
    local ItemDefs = require('src.items.item_loader')
    
    local oldItemId = ModuleEquipHelpers.unequipModuleFromSlot(droneId, slotType, ItemDefs)
    if not oldItemId then return nil end
    
    -- Clear the slot
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots then
            turretSlots.slots[1] = nil
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots then
            defensiveSlots.slots[1] = nil
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots then
            generatorSlots.slots[1] = nil
        end
    end
    
    return oldItemId
end

local LoadoutWindow = WindowBase:new{
    width = 850,
    height = 600,
    isOpen = false
}

-- Expose helpers for other modules to use
LoadoutWindow.ModuleEquipHelpers = ModuleEquipHelpers

-- Draw the panel inside an existing ship window (embedded mode)
function LoadoutWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return shipWin:drawLoadoutContent(windowX, windowY, width, height, alpha)
end

-- Delegate input to window when embedded
function LoadoutWindow.mousepressedEmbedded(shipWin, x, y, button)
    return shipWin:handleLoadoutMousepressed(x, y, button)
end
function LoadoutWindow.mousereleasedEmbedded(shipWin, x, y, button)
    return shipWin:handleLoadoutMousereleased(x, y, button)
end
function LoadoutWindow.mousemovedEmbedded(shipWin, x, y, dx, dy)
    return shipWin:handleLoadoutMousemoved(x, y, dx, dy)
end

-- Proxy useful APIs so ship code can keep calling the same names
function LoadoutWindow.equipModule(shipWin, itemId)
    local EntityHelpers = require('src.entity_helpers')
    local droneId = EntityHelpers.getPlayerShip()
    if not droneId then return false end
    
    return ModuleEquipHelpers.equipModule(droneId, itemId)
end
function LoadoutWindow.unequipModule(shipWin, slotType, itemId)
    return shipWin:unequipModuleInternal(slotType, itemId)
end
function LoadoutWindow.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
    return shipWin:drawEquipmentSlotInternal(slotName, equippedItemId, x, y, width, alpha, droneId)
end

-- Forwarders to parent ShipWindow if panels need to call back
function LoadoutWindow:openContextMenu(itemId, itemDef, x, y)
    if self.parentShipWindow and self.parentShipWindow.openContextMenu then
        return self.parentShipWindow:openContextMenu(itemId, itemDef, x, y)
    end
end

function LoadoutWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    return self:drawEquipmentSlotInternal(slotName, equippedItemId, x, y, width, alpha, droneId)
end

-- Instance method for equipModule (called from ShipWindow)
-- Preserve the original implementation in a local to avoid accidental recursion
local _equipModule_impl = LoadoutWindow.equipModule
function LoadoutWindow:equipModule(itemId)
    return _equipModule_impl(self, itemId)
end


function LoadoutWindow:canEquipInSlotInternal(itemId, slotType)
    return UIUtils.canEquipInSlot(itemId, slotType)
end

-- Helper methods (full implementations)
function LoadoutWindow:drawLoadoutContent(windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 8
    local contentWidth = width - 20
    local contentHeight = height - Theme.window.topBarHeight - (Theme.window.bottomBarHeight or 0) - 16
    
    -- Get player and drone using EntityHelpers
    local EntityHelpers = require('src.entity_helpers')
    local droneId = EntityHelpers.getPlayerShip()
    if not droneId then return end
    
    local slotSize = 120
    local slotPadding = 20
    local slotsStartY = contentY + 20
    
    -- Draw header
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("Equipment", contentX, contentY, contentWidth, "center")
    
    -- Draw equipment slots in a row using UIUtils slot helpers
    local slotX = contentX + (contentWidth - (slotSize * 3 + slotPadding * 2)) / 2
    local slotY = slotsStartY
    
    -- Turret Module slot
    local turretItemId = UIUtils.getSlotItem(droneId, "Turret Module")
    self:drawEquipmentSlotInternal("Turret Module", turretItemId, slotX, slotY, slotSize, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Defensive Module slot
    local defensiveItemId = UIUtils.getSlotItem(droneId, "Defensive Module")
    self:drawEquipmentSlotInternal("Defensive Module", defensiveItemId, slotX, slotY, slotSize, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Generator Module slot
    local generatorItemId = UIUtils.getSlotItem(droneId, "Generator Module")
    self:drawEquipmentSlotInternal("Generator Module", generatorItemId, slotX, slotY, slotSize, alpha, droneId)
    
    -- Draw Stats button below the equipment slots
    local btnH = 32
    local btnW = 140
    local btnY = slotY + slotSize + 30
    local btnX = contentX + (contentWidth - btnW) / 2
    
    -- Track button for click detection
    self.statsButtonRect = { x = btnX, y = btnY, w = btnW, h = btnH }
    
    local mx, my = UIUtils.getMousePosition()
    local isButtonHovered = UIUtils.pointInRect(mx, my, btnX, btnY, btnW, btnH)
    
    -- Draw button
    local bg = Theme.colors.surface
    local border = isButtonHovered and Theme.colors.hover or Theme.colors.border
    if isButtonHovered then
        love.graphics.setColor(0.2, 0.4, 0.6, 0.28 * alpha)
        love.graphics.rectangle("fill", btnX - 1, btnY - 1, btnW + 2, btnH + 2, 6, 6)
    end
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.9 * alpha)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 6, 6)
    
    -- Draw button text
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("View Stats", btnX, btnY + (btnH - love.graphics.getFont():getHeight()) / 2, btnW, "center")
end

function LoadoutWindow:unequipModuleInternal(slotType, itemId)
    local EntityHelpers = require('src.entity_helpers')
    local droneId = EntityHelpers.getPlayerShip()
    if not droneId then return false end
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return false end
    
    local oldItemId = ModuleEquipHelpers.unequipModule(droneId, slotType)
    if oldItemId then
        cargo:addItem(oldItemId, 1)
    end
    return true
end

function LoadoutWindow:drawEquipmentSlotInternal(slotName, equippedItemId, x, y, slotSize, alpha, droneId)
    local ItemDefs = require('src.items.item_loader')
    
    -- Get mouse position for hover detection
    local mx, my = UIUtils.getMousePosition()
    
    local isHovered = UIUtils.pointInRect(mx, my, x, y, slotSize, slotSize)
    if isHovered then
        self.hoveredSlot = {
            slotName = slotName,
            itemId = equippedItemId,
            x = x,
            y = y,
            width = slotSize,
            mouseX = mx,
            mouseY = my
        }
    end
    
    -- Draw slot background
    local bg = Theme.colors.surface
    local border = isHovered and Theme.colors.hover or Theme.colors.border
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.8 * alpha)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, 6, 6)
    love.graphics.setColor(border[1], border[2], border[3], 0.6 * alpha)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, 6, 6)
    
    -- Draw slot label
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    love.graphics.printf(slotName, x, y + slotSize - 20, slotSize, "center")
    
    -- Draw equipped item icon if present
    if equippedItemId then
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            local centerX = x + slotSize / 2
            local centerY = y + slotSize / 2 - 10
            UIUtils.drawItemIcon(itemDef, centerX, centerY, alpha, 1.33)
            
            -- Draw item name below icon
            local itemName = itemDef.name or equippedItemId
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
            love.graphics.printf(itemName, x, y + slotSize / 2 + 20, slotSize, "center")
        end
    else
        -- Empty slot - show placeholder text
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], 0.5 * alpha)
        love.graphics.printf("Empty", x, y + slotSize / 2 - 8, slotSize, "center")
    end
end

function LoadoutWindow:handleLoadoutMousepressed(x, y, button)
    -- Handle Stats button click
    if button == 1 and self.statsButtonRect then
        if UIUtils.pointInRect(x, y, self.statsButtonRect.x, self.statsButtonRect.y, self.statsButtonRect.w, self.statsButtonRect.h) then
            StatsWindow:toggle()
            -- Set focus if stats window is open
            if StatsWindow:getOpen() then
                local UISystem = require('src.systems.ui')
                UISystem.setWindowFocus('stats_window')
            end
            return true
        end
    end
    
    -- Start drag on left-click of an equipped slot
    if button == 1 and self.hoveredSlot and not ContextMenu.isOpen() and not self._blockDragUntilRelease then
        local hovered = self.hoveredSlot
        if hovered.itemId and hovered.slotName then
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[hovered.itemId]
            DragState.startDrag({ origin = "loadout", itemId = hovered.itemId, itemDef = itemDef, slotName = hovered.slotName, sourceWindow = self })
            return true
        end
    end

    -- Handle right-click on equipment slots to unequip
    if button == 2 and self.hoveredSlot then
        local hovered = self.hoveredSlot
        if hovered.itemId and hovered.slotName then
            -- Open context menu with unequip option
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[hovered.itemId]
            local itemName = (itemDef and itemDef.name) or tostring(hovered.itemId)
            
            ContextMenu.open({
                itemId = hovered.itemId,
                itemDef = itemDef,
                x = x,
                y = y,
                options = {
                    {
                        text = "Unequip " .. itemName,
                        action = "unequip",
                        slotType = hovered.slotName
                    }
                }
            }, function(option)
                if option.action == "unequip" then
                    self:unequipModuleInternal(option.slotType, hovered.itemId)
                end
            end)
            return true
        end
    end
    
    return false
end

function LoadoutWindow:handleLoadoutMousereleased(x, y, button)
    -- Handle drop of dragged items
    if button == 1 and DragState.hasDrag() then
        local dragged = DragState.getDragItem()
        if not dragged then return false end

        -- Use UIUtils slot helpers instead of local functions

        -- Cargo -> Loadout
        if dragged.origin == "cargo" then
            -- If we're hovering a slot
            if self.hoveredSlot and self.hoveredSlot.slotName then
                local slotName = self.hoveredSlot.slotName
                if self:canEquipInSlotInternal(dragged.itemId, slotName) then
                    local ok = self:equipModule(dragged.itemId)
                    if ok then DragState.endDrag() end
                    return true
                else
                    -- Incompatible: just return to inventory
                    DragState.endDrag()
                    return true
                end
            else
                -- Dropped outside any slot: return to inventory
                DragState.endDrag()
                return true
            end

        -- Loadout -> (swap or return to inventory)
        elseif dragged.origin == "loadout" then
            local srcSlot = dragged.slotName

            -- Get drone id using EntityHelpers
            local EntityHelpers = require('src.entity_helpers')
            local droneId = EntityHelpers.getPlayerShip()
            if not droneId then
                DragState.endDrag()
                return true
            end

            if self.hoveredSlot and self.hoveredSlot.slotName then
                local targetSlot = self.hoveredSlot.slotName
                -- Dropped back onto same slot -> cancel
                if targetSlot == srcSlot then
                    DragState.endDrag()
                    return true
                end

                if self:canEquipInSlotInternal(dragged.itemId, targetSlot) then
                    -- Swap items between srcSlot and targetSlot using UIUtils
                    local targetOld = UIUtils.getSlotItem(droneId, targetSlot)
                    -- Place dragged item into target
                    UIUtils.setSlotItem(droneId, targetSlot, dragged.itemId)
                    -- Put previous occupant (if any) into source slot
                    UIUtils.setSlotItem(droneId, srcSlot, targetOld)
                    DragState.endDrag()
                    return true
                else
                    -- Incompatible target: return dragged item to inventory
                    self:unequipModuleInternal(srcSlot, dragged.itemId)
                    DragState.endDrag()
                    return true
                end
            else
                -- Dropped outside any slot: return to inventory
                self:unequipModuleInternal(srcSlot, dragged.itemId)
                DragState.endDrag()
                return true
            end
        end
    end

    return false
end

function LoadoutWindow:handleLoadoutMousemoved(x, y, dx, dy)
    return false
end

-- Standalone window needs context menu drawing
function LoadoutWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    self:drawLoadoutContent(x, y, self.width, self.height, alpha)
    
    -- Draw context menu if open
    if ContextMenu.isOpen() then
        ContextMenu.draw(alpha)
    end
end

function LoadoutWindow:mousepressed(x, y, button)
    -- Close context menu if clicking outside of it
    if ContextMenu.isOpen() then
        local menu = ContextMenu.getMenu()
        if UIUtils.shouldCloseContextMenu(menu, x, y) then
            ContextMenu.close()
            return
        end
    end
    
    -- Let base handle close button and dragging first
    WindowBase.mousepressed(self, x, y, button)
    -- If close button was pressed, WindowBase:setOpen(false) will have been called
    if not self:getOpen() then return true end
    -- If user started dragging the window, consume the event
    if self.isDragging then return true end

    return self:handleLoadoutMousepressed(x, y, button)
end

function LoadoutWindow:mousereleased(x, y, button)
    if button == 1 and ContextMenu.isOpen() then
        if ContextMenu.handleClickAt(x, y) then
            return
        end
    end
    
    WindowBase.mousereleased(self, x, y, button)
    return self:handleLoadoutMousereleased(x, y, button)
end

function LoadoutWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if ContextMenu.isOpen() then
        ContextMenu.mousemoved(x, y)
    end
    
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    return self:handleLoadoutMousemoved(x, y, dx, dy)
end

function LoadoutWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and ContextMenu.isOpen() then
        ContextMenu.close()
        return true
    end
    return false
end

return LoadoutWindow


