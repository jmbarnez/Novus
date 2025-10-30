---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local LoadoutPanel = require('src.ui.loadout_panel')

local LoadoutWindow = WindowBase:new{
    width = 850,
    height = 600,
    isOpen = false
}

-- Draw the panel inside an existing ship window (embedded mode)
function LoadoutWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return LoadoutPanel.draw(shipWin, windowX, windowY, width, height, alpha)
end

-- Delegate input to the panel when embedded
function LoadoutWindow.mousepressedEmbedded(shipWin, x, y, button)
    if LoadoutPanel and LoadoutPanel.mousepressed then
        return LoadoutPanel.mousepressed(shipWin, x, y, button)
    end
end
function LoadoutWindow.mousereleasedEmbedded(shipWin, x, y, button)
    if LoadoutPanel and LoadoutPanel.mousereleased then
        return LoadoutPanel.mousereleased(shipWin, x, y, button)
    end
end
function LoadoutWindow.mousemovedEmbedded(shipWin, x, y, dx, dy)
    if LoadoutPanel and LoadoutPanel.mousemoved then
        return LoadoutPanel.mousemoved(shipWin, x, y, dx, dy)
    end
end

-- Proxy useful APIs so ship code can keep calling the same names
function LoadoutWindow.equipModule(shipWin, itemId)
    return LoadoutPanel.equipModule(shipWin, itemId)
end
function LoadoutWindow.unequipModule(shipWin, slotType, itemId)
    return LoadoutPanel.unequipModule(shipWin, slotType, itemId)
end
function LoadoutWindow.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
    return LoadoutPanel.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
end

-- Forwarders to parent ShipWindow if panels need to call back
function LoadoutWindow:openContextMenu(itemId, itemDef, x, y)
    if self.parentShipWindow and self.parentShipWindow.openContextMenu then
        return self.parentShipWindow:openContextMenu(itemId, itemDef, x, y)
    end
end

function LoadoutWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    return LoadoutPanel.drawEquipmentSlot(self, slotName, equippedItemId, x, y, width, alpha, droneId)
end

-- Standalone window behaviour (if opened independently)
function LoadoutWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    LoadoutPanel.draw(self, x, y, self.width, self.height, alpha)
end

function LoadoutWindow:mousepressed(x, y, button)
    -- Let base handle close button and dragging first
    WindowBase.mousepressed(self, x, y, button)
    -- If close button was pressed, WindowBase:setOpen(false) will have been called
    if not self:getOpen() then return true end
    -- If user started dragging the window, consume the event
    if self.isDragging then return true end

    if LoadoutPanel and LoadoutPanel.mousepressed then
        return LoadoutPanel.mousepressed(self, x, y, button)
    end
end
function LoadoutWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
    if LoadoutPanel and LoadoutPanel.mousereleased then
        return LoadoutPanel.mousereleased(self, x, y, button)
    end
end
function LoadoutWindow:mousemoved(x, y, dx, dy)
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    if LoadoutPanel and LoadoutPanel.mousemoved then
        return LoadoutPanel.mousemoved(self, x, y, dx, dy)
    end
end

return LoadoutWindow


