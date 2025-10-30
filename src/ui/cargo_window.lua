---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local CargoPanel = require('src.ui.cargo_panel')
local ContextMenu = require('src.ui.context_menu')
local ECS = require('src.ecs')

local CargoWindow = WindowBase:new{
    width = 900,
    height = 650,
    isOpen = false
}

function CargoWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return CargoPanel.draw(shipWin, windowX, windowY, width, height, alpha)
end

function CargoWindow.drawCargoGrid(shipWin, cargoItems, x, y, width, height, alpha)
    return CargoPanel.drawCargoGrid(shipWin, cargoItems, x, y, width, height, alpha)
end

function CargoWindow.getCompatibleSlots(shipWin, itemId)
    return CargoPanel.getCompatibleSlots(shipWin, itemId)
end

function CargoWindow.mousepressedEmbedded(shipWin, x, y, button)
    if CargoPanel and CargoPanel.mousepressed then
        return CargoPanel.mousepressed(shipWin, x, y, button)
    end
end
function CargoWindow.mousereleasedEmbedded(shipWin, x, y, button)
    if CargoPanel and CargoPanel.mousereleased then
        return CargoPanel.mousereleased(shipWin, x, y, button)
    end
end
function CargoWindow.mousemovedEmbedded(shipWin, x, y, dx, dy)
    if CargoPanel and CargoPanel.mousemoved then
        return CargoPanel.mousemoved(shipWin, x, y, dx, dy)
    end
end
function CargoWindow.keypressedEmbedded(shipWin, key)
    if CargoPanel and CargoPanel.keypressed then
        return CargoPanel.keypressed(shipWin, key)
    end
end
function CargoWindow.textinputEmbedded(shipWin, t)
    if CargoPanel and CargoPanel.textinput then
        return CargoPanel.textinput(shipWin, t)
    end
end

-- Get compatible equipment slots for an item
function CargoWindow:getCompatibleSlots(itemId)
    return CargoPanel.getCompatibleSlots(self, itemId)
end

-- Check if item can be equipped in a specific slot type
function CargoWindow:canEquipInSlot(itemId, slotType)
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

-- Equip a module (delegates to LoadoutWindow when parented, or uses LoadoutPanel directly)
function CargoWindow:equipModule(itemId)
    if self.parentShipWindow and self.parentShipWindow.loadoutWindow then
        return self.parentShipWindow.loadoutWindow:equipModule(itemId)
    else
        -- Standalone mode: use LoadoutPanel directly with self as shipWin
        local LoadoutPanel = require('src.ui.loadout_panel')
        return LoadoutPanel.equipModule(self, itemId)
    end
end

-- Open context menu for cargo items
function CargoWindow:openContextMenu(itemId, itemDef, x, y)
    -- If parented, forward to parent
    if self.parentShipWindow and self.parentShipWindow.openContextMenu then
        return self.parentShipWindow:openContextMenu(itemId, itemDef, x, y)
    end
    
    -- Standalone mode: implement context menu
    local compatibleSlots = self:getCompatibleSlots(itemId)
    local options = {}

    -- Determine drone and slot occupancy so we can show "Swap" when occupied
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local droneId = nil
    if #pilotEntities > 0 then
        local pilotId = pilotEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then droneId = input.targetEntity end
    end

    for _, slotType in ipairs(compatibleSlots) do
        local occupied = false
        if droneId then
            if slotType == "Turret Module" then
                local turretSlots = ECS.getComponent(droneId, "TurretSlots")
                occupied = (turretSlots and turretSlots.slots and turretSlots.slots[1]) ~= nil
            elseif slotType == "Defensive Module" then
                local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
                occupied = (defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1]) ~= nil
            elseif slotType == "Generator Module" then
                local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
                occupied = (generatorSlots and generatorSlots.slots and generatorSlots.slots[1]) ~= nil
            end
        end

        local itemName = (itemDef and itemDef.name) or tostring(itemId)
        local optionText
        if occupied then
            optionText = "Swap " .. itemName .. " with " .. slotType
        else
            optionText = "Equip " .. itemName .. " to " .. slotType
        end

        table.insert(options, {
            text = optionText,
            action = "equip",
            slotType = slotType
        })
    end

    -- If no compatible slots, show a single disabled line
    if #options == 0 then
        table.insert(options, { text = "No compatible slots", action = "noop" })
    end

    ContextMenu.open({
        itemId = itemId,
        itemDef = itemDef,
        x = x,
        y = y,
        options = options
    }, function(option)
        if option.action == "equip" then
            self:equipModule(itemId)
        end
    end)
end

function CargoWindow:handleContextMenuClick(optionIndex)
    if self.parentShipWindow and self.parentShipWindow.handleContextMenuClick then
        return self.parentShipWindow:handleContextMenuClick(optionIndex)
    end
end

function CargoWindow:drawContextMenu(x, y, alpha)
    if self.parentShipWindow and self.parentShipWindow.drawContextMenu then
        return self.parentShipWindow:drawContextMenu(x, y, alpha)
    end
end

function CargoWindow:isSearchFocused()
    return self.cargoSearchFocused == true
end

-- Standalone window behaviour
function CargoWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    CargoPanel.draw(self, x, y, self.width, self.height, alpha)
    
    -- Draw context menu if open
    if ContextMenu.isOpen() then
        ContextMenu.draw(alpha)
    end
end

function CargoWindow:mousepressed(x, y, button)
    -- Close context menu if clicking outside of it (any button)
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

    if CargoPanel and CargoPanel.mousepressed then
        return CargoPanel.mousepressed(self, x, y, button)
    end
end
function CargoWindow:mousereleased(x, y, button)
    if button == 1 and ContextMenu.isOpen() then
        if ContextMenu.handleClickAt(x, y) then
            return
        end
    end
    
    WindowBase.mousereleased(self, x, y, button)
    if CargoPanel and CargoPanel.mousereleased then
        return CargoPanel.mousereleased(self, x, y, button)
    end
end
function CargoWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if ContextMenu.isOpen() then
        ContextMenu.mousemoved(x, y)
    end
    
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    if CargoPanel and CargoPanel.mousemoved then
        return CargoPanel.mousemoved(self, x, y, dx, dy)
    end
end
function CargoWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and ContextMenu.isOpen() then
        ContextMenu.close()
        return true
    end
    
    if CargoPanel and CargoPanel.keypressed then
        return CargoPanel.keypressed(self, key)
    end
    return false
end
function CargoWindow:textinput(t)
    if CargoPanel and CargoPanel.textinput then
        return CargoPanel.textinput(self, t)
    end
    return false
end

return CargoWindow


