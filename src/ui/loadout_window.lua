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
            -- Store the canonical module id/name (used by turret systems/registry), not the itemId
            if itemDef and itemDef.module then
                local mod = itemDef.module
                turret.moduleName = mod.id or mod.name or (itemId:gsub("_module$", ""))
            else
                turret.moduleName = itemId
            end
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
    
    -- Show notification
    local Notifications = require('src.ui.notifications')
    if Notifications then
        local newItemName = itemDef.name or itemId
        if oldItemId then
            -- Swapped modules
            local oldItemDef = ItemDefs[oldItemId]
            local oldItemName = (oldItemDef and oldItemDef.name) or oldItemId
            Notifications.addNotification({
                type = 'equipment',
                text = string.format("Swapped %s → %s", oldItemName, newItemName),
                timer = 3.0
            })
        else
            -- New equipment
            Notifications.addNotification({
                type = 'equipment',
                text = string.format("Equipped: %s", newItemName),
                timer = 3.0
            })
        end
    end
    
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
    
    -- Show notification
    local Notifications = require('src.ui.notifications')
    if Notifications and oldItemId then
        local ItemDefs = require('src.items.item_loader')
        local oldItemDef = ItemDefs[oldItemId]
        local oldItemName = (oldItemDef and oldItemDef.name) or oldItemId
        Notifications.addNotification({
            type = 'equipment',
            text = string.format("Unequipped: %s", oldItemName),
            timer = 3.0
        })
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

-- Helper to get sub-slot item (sub-slots are indices 2, 3, 4 in the slots array)
function LoadoutWindow:getSubSlotItem(droneId, slotType, subSlotIndex)
    local ECS = require('src.ecs')
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots and turretSlots.slots[subSlotIndex + 1] then
            return turretSlots.slots[subSlotIndex + 1]  -- +1 because subSlotIndex is 1-3, array indices are 2-4
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[subSlotIndex + 1] then
            return defensiveSlots.slots[subSlotIndex + 1]
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots and generatorSlots.slots[subSlotIndex + 1] then
            return generatorSlots.slots[subSlotIndex + 1]
        end
    end
    return nil
end

-- Helper to set sub-slot item
function LoadoutWindow:setSubSlotItem(droneId, slotType, subSlotIndex, itemId)
    local ECS = require('src.ecs')
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots then
            turretSlots.slots[subSlotIndex + 1] = itemId
            return true
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots then
            defensiveSlots.slots[subSlotIndex + 1] = itemId
            return true
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots then
            generatorSlots.slots[subSlotIndex + 1] = itemId
            return true
        end
    end
    return false
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
    local subSlotSize = 32
    local subSlotPadding = 4
    local subSlotSpacing = 8
    
    -- Turret Module slot
    local turretItemId = UIUtils.getSlotItem(droneId, "Turret Module")
    self:drawEquipmentSlotInternal("Turret Module", turretItemId, slotX, slotY, slotSize, alpha, droneId)
    -- Draw 3 sub-slots below turret slot
    self:drawSubSlots("Turret Module", slotX + (slotSize - (subSlotSize * 3 + subSlotPadding * 2)) / 2, slotY + slotSize + subSlotSpacing, subSlotSize, subSlotPadding, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Defensive Module slot
    local defensiveItemId = UIUtils.getSlotItem(droneId, "Defensive Module")
    self:drawEquipmentSlotInternal("Defensive Module", defensiveItemId, slotX, slotY, slotSize, alpha, droneId)
    -- Draw 3 sub-slots below defensive slot
    self:drawSubSlots("Defensive Module", slotX + (slotSize - (subSlotSize * 3 + subSlotPadding * 2)) / 2, slotY + slotSize + subSlotSpacing, subSlotSize, subSlotPadding, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Generator Module slot
    local generatorItemId = UIUtils.getSlotItem(droneId, "Generator Module")
    self:drawEquipmentSlotInternal("Generator Module", generatorItemId, slotX, slotY, slotSize, alpha, droneId)
    -- Draw 3 sub-slots below generator slot
    self:drawSubSlots("Generator Module", slotX + (slotSize - (subSlotSize * 3 + subSlotPadding * 2)) / 2, slotY + slotSize + subSlotSpacing, subSlotSize, subSlotPadding, alpha, droneId)
    
    -- Draw Stats button below the equipment slots (accounting for sub-slots)
    local btnH = 32
    local btnW = 140
    local btnY = slotY + slotSize + subSlotSize + subSlotSpacing + 30
    local btnX = contentX + (contentWidth - btnW) / 2
    
    -- Track button for click detection
    self.statsButtonRect = { x = btnX, y = btnY, w = btnW, h = btnH }
    
    local mx, my = UIUtils.getMousePosition()
    local isButtonHovered = UIUtils.pointInRect(mx, my, btnX, btnY, btnW, btnH)
    
    -- Draw button with blue background and white text
    local cornerRadius = Theme.window.cornerRadius or 0
    local blueBg = isButtonHovered and {0.2, 0.5, 0.9, 1} or {0.15, 0.4, 0.85, 1}  -- Lighter blue on hover
    love.graphics.setColor(blueBg[1], blueBg[2], blueBg[3], alpha)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, cornerRadius, cornerRadius)
    
    -- Optional border (subtle)
    love.graphics.setColor(0.1, 0.3, 0.7, 0.5 * alpha)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, cornerRadius, cornerRadius)
    
    -- Draw button text in white
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(1, 1, 1, alpha)  -- White text
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

function LoadoutWindow:drawSubSlots(slotName, startX, startY, subSlotSize, subSlotPadding, alpha, droneId)
    local ItemDefs = require('src.items.item_loader')
    local mx, my = UIUtils.getMousePosition()
    local currentX = startX
    
    for i = 1, 3 do
        local itemId = self:getSubSlotItem(droneId, slotName, i)
        local isHovered = UIUtils.pointInRect(mx, my, currentX, startY, subSlotSize, subSlotSize)
        
        if isHovered then
            self.hoveredSlot = {
                slotName = slotName,
                itemId = itemId,
                x = currentX,
                y = startY,
                width = subSlotSize,
                mouseX = mx,
                mouseY = my,
                isSubSlot = true,
                subSlotIndex = i
            }
        end
        
        -- Draw sub-slot background
        local bg = Theme.colors.surfaceAlt or Theme.colors.surface
        local border = isHovered and Theme.colors.hover or Theme.colors.border
        local cornerRadius = 2
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.7 * alpha)
        love.graphics.rectangle("fill", currentX, startY, subSlotSize, subSlotSize, cornerRadius, cornerRadius)
        love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
        love.graphics.rectangle("line", currentX, startY, subSlotSize, subSlotSize, cornerRadius, cornerRadius)
        
        -- Draw item icon if present
        if itemId then
            local itemDef = ItemDefs[itemId]
            if itemDef then
                local centerX = currentX + subSlotSize / 2
                local centerY = startY + subSlotSize / 2
                UIUtils.drawItemIcon(itemDef, centerX, centerY, alpha, 0.8)
            end
        end
        
        currentX = currentX + subSlotSize + subSlotPadding
    end
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
            mouseY = my,
            isSubSlot = false
        }
    end
    
    -- Draw slot background
    local bg = Theme.colors.surface
    local border = isHovered and Theme.colors.hover or Theme.colors.border
    local cornerRadius = Theme.window.cornerRadius or 0
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.8 * alpha)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, cornerRadius, cornerRadius)
    love.graphics.setColor(border[1], border[2], border[3], 0.6 * alpha)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, cornerRadius, cornerRadius)
    
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
    
    -- Start drag on left-click of an equipped slot (main or sub-slot)
    if button == 1 and self.hoveredSlot and not ContextMenu.isOpen() and not self._blockDragUntilRelease then
        local hovered = self.hoveredSlot
        if hovered.itemId and hovered.slotName then
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[hovered.itemId]
            DragState.startDrag({ 
                origin = "loadout", 
                itemId = hovered.itemId, 
                itemDef = itemDef, 
                slotName = hovered.slotName, 
                sourceWindow = self,
                isSubSlot = hovered.isSubSlot,
                subSlotIndex = hovered.subSlotIndex
            })
            return true
        end
    end

    -- Handle right-click on equipment slots to unequip
    if button == 2 and self.hoveredSlot then
        local hovered = self.hoveredSlot
        if hovered.isSubSlot and hovered.subSlotIndex then
            -- Right-click on sub-slot to unequip
            local EntityHelpers = require('src.entity_helpers')
            local ECS = require('src.ecs')
            local droneId = EntityHelpers.getPlayerShip()
            if droneId then
                local oldItemId = self:getSubSlotItem(droneId, hovered.slotName, hovered.subSlotIndex)
                if oldItemId then
                    local cargo = ECS.getComponent(droneId, "Cargo")
                    if cargo then
                        cargo:addItem(oldItemId, 1)
                        self:setSubSlotItem(droneId, hovered.slotName, hovered.subSlotIndex, nil)
                        return true
                    end
                end
            end
        elseif hovered.itemId and hovered.slotName then
            -- Right-click directly unequips the module without showing context menu
            self:unequipModuleInternal(hovered.slotName, hovered.itemId)
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
                local EntityHelpers = require('src.entity_helpers')
                local ECS = require('src.ecs')
                local droneId = EntityHelpers.getPlayerShip()
                local cargo = ECS.getComponent(droneId, "Cargo")
                
                -- Check if hovering a sub-slot
                if self.hoveredSlot.isSubSlot and self.hoveredSlot.subSlotIndex and droneId and cargo then
                    -- Check if item is compatible (same type as main slot)
                    if self:canEquipInSlotInternal(dragged.itemId, slotName) then
                        -- Check if cargo has the item
                        if cargo.items[dragged.itemId] and cargo.items[dragged.itemId] > 0 then
                            -- Swap if sub-slot already has item
                            local oldItemId = self:getSubSlotItem(droneId, slotName, self.hoveredSlot.subSlotIndex)
                            if oldItemId then
                                cargo:addItem(oldItemId, 1)
                            end
                            -- Equip new item to sub-slot
                            cargo:removeItem(dragged.itemId, 1)
                            self:setSubSlotItem(droneId, slotName, self.hoveredSlot.subSlotIndex, dragged.itemId)
                            DragState.endDrag()
                            return true
                        end
                    end
                    -- Incompatible or no item: just return to inventory
                    DragState.endDrag()
                    return true
                elseif self:canEquipInSlotInternal(dragged.itemId, slotName) then
                    -- Main slot
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
            local srcIsSubSlot = dragged.isSubSlot
            local srcSubSlotIndex = dragged.subSlotIndex

            -- Get drone id using EntityHelpers
            local EntityHelpers = require('src.entity_helpers')
            local ECS = require('src.ecs')
            local droneId = EntityHelpers.getPlayerShip()
            if not droneId then
                DragState.endDrag()
                return true
            end
            local cargo = ECS.getComponent(droneId, "Cargo")
            if not cargo then
                DragState.endDrag()
                return true
            end

            if self.hoveredSlot and self.hoveredSlot.slotName then
                local targetSlot = self.hoveredSlot.slotName
                local targetIsSubSlot = self.hoveredSlot.isSubSlot
                local targetSubSlotIndex = self.hoveredSlot.subSlotIndex
                
                -- Dropped back onto same slot -> cancel
                if targetSlot == srcSlot and targetIsSubSlot == srcIsSubSlot and targetSubSlotIndex == srcSubSlotIndex then
                    DragState.endDrag()
                    return true
                end

                if self:canEquipInSlotInternal(dragged.itemId, targetSlot) then
                    if targetIsSubSlot and targetSubSlotIndex then
                        -- Dropping onto sub-slot
                        local oldItemId = self:getSubSlotItem(droneId, targetSlot, targetSubSlotIndex)
                        if oldItemId then
                            cargo:addItem(oldItemId, 1)
                        end
                        self:setSubSlotItem(droneId, targetSlot, targetSubSlotIndex, dragged.itemId)
                        
                        -- Remove from source (sub-slot or main slot)
                        if srcIsSubSlot and srcSubSlotIndex then
                            self:setSubSlotItem(droneId, srcSlot, srcSubSlotIndex, nil)
                        else
                            self:unequipModuleInternal(srcSlot, dragged.itemId)
                        end
                        DragState.endDrag()
                        return true
                    else
                        -- Dropping onto main slot
                        local targetOld = UIUtils.getSlotItem(droneId, targetSlot)
                        -- Place dragged item into target
                        UIUtils.setSlotItem(droneId, targetSlot, dragged.itemId)
                        -- Put previous occupant (if any) back to source
                        if srcIsSubSlot and srcSubSlotIndex then
                            if targetOld then
                                self:setSubSlotItem(droneId, srcSlot, srcSubSlotIndex, targetOld)
                            else
                                self:setSubSlotItem(droneId, srcSlot, srcSubSlotIndex, nil)
                            end
                        else
                            UIUtils.setSlotItem(droneId, srcSlot, targetOld)
                        end
                        DragState.endDrag()
                        return true
                    end
                else
                    -- Incompatible target: return dragged item to inventory
                    if srcIsSubSlot and srcSubSlotIndex then
                        cargo:addItem(dragged.itemId, 1)
                        self:setSubSlotItem(droneId, srcSlot, srcSubSlotIndex, nil)
                    else
                        self:unequipModuleInternal(srcSlot, dragged.itemId)
                    end
                    DragState.endDrag()
                    return true
                end
            else
                -- Dropped outside any slot: return to inventory
                if srcIsSubSlot and srcSubSlotIndex then
                    cargo:addItem(dragged.itemId, 1)
                    self:setSubSlotItem(droneId, srcSlot, srcSubSlotIndex, nil)
                else
                    self:unequipModuleInternal(srcSlot, dragged.itemId)
                end
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


