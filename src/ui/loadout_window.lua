---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local ContextMenu = require('src.ui.context_menu')
local DragState = require('src.ui.drag_state')

local LoadoutWindow = WindowBase:new{
    width = 850,
    height = 600,
    isOpen = false
}

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
    -- Implement equip logic directly to avoid circular dependency with LoadoutPanel stub
    local ECS = require('src.ecs')
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return false end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return false end
    local droneId = input.targetEntity
    
    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return false end
    
    -- Determine slot type based on item type
    local slotType = nil
    if itemDef.type == "turret" then
        slotType = "Turret Module"
    elseif itemDef.type == "shield" or string.match(itemId, "shield") then
        slotType = "Defensive Module"
    elseif itemDef.type == "generator" then
        slotType = "Generator Module"
    else
        return false -- Can't equip this item
    end
    
    -- Get cargo to remove item from
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return false end
    
    -- Check if item exists in cargo
    if not cargo.items[itemId] or cargo.items[itemId] < 1 then
        return false
    end
    
    -- Handle unequipping existing item if slot is occupied
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots and turretSlots.slots[1] then
            local oldItemId = turretSlots.slots[1]
            cargo:addItem(oldItemId, 1) -- Add old item back to cargo
        end
        turretSlots.slots[1] = itemId
        -- Also update Turret component
        local turret = ECS.getComponent(droneId, "Turret")
        if turret then
            turret.moduleName = itemId
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if not defensiveSlots then return false end
        
        -- Unequip old defensive module if present
        if defensiveSlots.slots and defensiveSlots.slots[1] then
            local oldItemId = defensiveSlots.slots[1]
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            cargo:addItem(oldItemId, 1)
        end
        
        -- Equip new defensive module
        defensiveSlots.slots[1] = itemId
        if itemDef.module and itemDef.module.equip then
            itemDef.module.equip(droneId)
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if not generatorSlots then return false end
        
        -- Unequip old generator module if present
        if generatorSlots.slots and generatorSlots.slots[1] then
            local oldItemId = generatorSlots.slots[1]
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            cargo:addItem(oldItemId, 1)
        end
        
        -- Equip new generator module
        generatorSlots.slots[1] = itemId
        if itemDef.module and itemDef.module.equip then
            itemDef.module.equip(droneId)
        end
    end
    
    -- Remove item from cargo
    cargo:removeItem(itemId, 1)
    
    return true
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

-- Helper function for point-in-rectangle test
local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function LoadoutWindow:canEquipInSlotInternal(itemId, slotType)
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

-- Helper methods (full implementations)
function LoadoutWindow:drawLoadoutContent(windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 8
    local contentWidth = width - 20
    local contentHeight = height - Theme.window.topBarHeight - (Theme.window.bottomBarHeight or 0) - 16
    
    -- Get player and drone
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    
    -- Get equipment slots
    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
    
    local slotSize = 120
    local slotPadding = 20
    local slotsStartY = contentY + 20
    
    -- Draw header
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("Equipment", contentX, contentY, contentWidth, "center")
    
    -- Draw equipment slots in a row
    local slotX = contentX + (contentWidth - (slotSize * 3 + slotPadding * 2)) / 2
    local slotY = slotsStartY
    
    -- Turret Module slot
    local turretItemId = turretSlots and turretSlots.slots and turretSlots.slots[1]
    self:drawEquipmentSlotInternal("Turret Module", turretItemId, slotX, slotY, slotSize, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Defensive Module slot
    local defensiveItemId = defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1]
    self:drawEquipmentSlotInternal("Defensive Module", defensiveItemId, slotX, slotY, slotSize, alpha, droneId)
    slotX = slotX + slotSize + slotPadding
    
    -- Generator Module slot
    local generatorItemId = generatorSlots and generatorSlots.slots and generatorSlots.slots[1]
    self:drawEquipmentSlotInternal("Generator Module", generatorItemId, slotX, slotY, slotSize, alpha, droneId)
end

function LoadoutWindow:unequipModuleInternal(slotType, itemId)
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return false end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return false end
    local droneId = input.targetEntity
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return false end
    
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots and turretSlots.slots[1] then
            cargo:addItem(turretSlots.slots[1], 1)
            turretSlots.slots[1] = nil
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1] then
            local oldItemId = defensiveSlots.slots[1]
            local ItemDefs = require('src.items.item_loader')
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            cargo:addItem(oldItemId, 1)
            defensiveSlots.slots[1] = nil
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots and generatorSlots.slots[1] then
            local oldItemId = generatorSlots.slots[1]
            local ItemDefs = require('src.items.item_loader')
            local oldItemDef = ItemDefs[oldItemId]
            if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                oldItemDef.module.unequip(droneId)
            end
            cargo:addItem(oldItemId, 1)
            generatorSlots.slots[1] = nil
        end
    end
    return true
end

function LoadoutWindow:drawEquipmentSlotInternal(slotName, equippedItemId, x, y, slotSize, alpha, droneId)
    local ItemDefs = require('src.items.item_loader')
    
    -- Get mouse position for hover detection
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    
    local isHovered = pointInRect(mx, my, x, y, slotSize, slotSize)
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
            love.graphics.push()
            love.graphics.translate(centerX, centerY)
            love.graphics.setColor(1, 1, 1, alpha)
            
            -- Check if this is a turret/module item (module is stored in itemDef.module)
            local module = itemDef.module
            local design = itemDef.design or (module and module.design)
            local drawFunc = itemDef.draw or (module and module.draw)
            
            if drawFunc and type(drawFunc) == "function" then
                -- Use the module's draw function if available, otherwise item's draw
                if module and module.draw then
                    module.draw(module, 0, 0)
                else
                    drawFunc(itemDef, 0, 0)
                end
            elseif design and design.color then
                -- Fallback: draw a colored circle/square based on design
                local color = design.color
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                local size = (design.size or 16) * 2
                love.graphics.circle("fill", 0, 0, size)
            else
                -- Ultimate fallback: simple colored square
                love.graphics.setColor(0.7, 0.7, 0.7, alpha)
                love.graphics.rectangle("fill", -16, -16, 32, 32, 2, 2)
            end
            love.graphics.pop()
            
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

        -- Helper accessors for slot components
        local function get_slot(droneId, slotType)
            if slotType == "Turret Module" then
                local s = ECS.getComponent(droneId, "TurretSlots")
                return s and s.slots and s.slots[1]
            elseif slotType == "Defensive Module" then
                local s = ECS.getComponent(droneId, "DefensiveSlots")
                return s and s.slots and s.slots[1]
            elseif slotType == "Generator Module" then
                local s = ECS.getComponent(droneId, "GeneratorSlots")
                return s and s.slots and s.slots[1]
            end
            return nil
        end

        local function set_slot(droneId, slotType, itemId)
            if slotType == "Turret Module" then
                local s = ECS.getComponent(droneId, "TurretSlots")
                if s and s.slots then
                    s.slots[1] = itemId
                end
                local turret = ECS.getComponent(droneId, "Turret")
                if turret then
                    turret.moduleName = itemId
                end
            elseif slotType == "Defensive Module" then
                local s = ECS.getComponent(droneId, "DefensiveSlots")
                if s and s.slots then s.slots[1] = itemId end
            elseif slotType == "Generator Module" then
                local s = ECS.getComponent(droneId, "GeneratorSlots")
                if s and s.slots then s.slots[1] = itemId end
            end
        end

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

            -- Find drone id
            local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
            if #pilotEntities == 0 then
                DragState.endDrag()
                return true
            end
            local pilotId = pilotEntities[1]
            local input = ECS.getComponent(pilotId, "InputControlled")
            if not input or not input.targetEntity then
                DragState.endDrag()
                return true
            end
            local droneId = input.targetEntity

            if self.hoveredSlot and self.hoveredSlot.slotName then
                local targetSlot = self.hoveredSlot.slotName
                -- Dropped back onto same slot -> cancel
                if targetSlot == srcSlot then
                    DragState.endDrag()
                    return true
                end

                if self:canEquipInSlotInternal(dragged.itemId, targetSlot) then
                    -- Swap items between srcSlot and targetSlot
                    local targetOld = get_slot(droneId, targetSlot)
                    -- Place dragged item into target
                    set_slot(droneId, targetSlot, dragged.itemId)
                    -- Put previous occupant (if any) into source slot
                    set_slot(droneId, srcSlot, targetOld)
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
        local cmW = menu.width or 200
        local cmH = menu.height or ((menu.paddingY or 12) * 2 + (#menu.options * (menu.optionHeight or 24)))
        if not (x >= menu.x and x <= menu.x + cmW and
            y >= menu.y and y <= menu.y + cmH) then
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


