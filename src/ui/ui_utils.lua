---@diagnostic disable: undefined-global
-- Shared UI utilities module
-- Provides common helper functions for UI components

local Scaling = require('src.scaling')
local Theme = require('src.ui.plasma_theme')

local UIUtils = {}

-- Point-in-rectangle test
-- @param px, py: point coordinates
-- @param rx, ry, rw, rh: rectangle position and size
function UIUtils.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Get current mouse position in UI coordinates
-- @return mx, my: mouse coordinates in UI space
function UIUtils.getMousePosition()
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        return Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        return Scaling.toUI(love.mouse.getPosition())
    end
end

-- Draw an item icon/icon (for use in cargo grids, equipment slots, etc.)
-- @param itemDef: item definition table
-- @param centerX, centerY: center position to draw at
-- @param alpha: alpha multiplier for drawing
-- @param iconScale: optional scale multiplier (default 1.0)
function UIUtils.drawItemIcon(itemDef, centerX, centerY, alpha, iconScale)
    if not itemDef then return end
    
    alpha = alpha or 1.0
    iconScale = iconScale or 1.0
    
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
        local size = (design.size or 16) * 1.5 * iconScale
        love.graphics.circle("fill", 0, 0, size)
    else
        -- Ultimate fallback: simple colored square
        local fallbackSize = 24 * iconScale
        love.graphics.setColor(0.7, 0.7, 0.7, alpha)
        love.graphics.rectangle("fill", -fallbackSize/2, -fallbackSize/2, fallbackSize, fallbackSize, 2, 2)
    end
    
    love.graphics.pop()
end

-- Check if an item can be equipped in a specific slot type
-- @param itemId: item identifier
-- @param slotType: slot type string ("Turret Module", "Defensive Module", "Generator Module")
-- @return boolean
function UIUtils.canEquipInSlot(itemId, slotType)
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

-- Get compatible slot types for an item
-- @param itemId: item identifier
-- @return array of compatible slot type strings
function UIUtils.getCompatibleSlots(itemId)
    local compatibleSlots = {}
    if UIUtils.canEquipInSlot(itemId, "Turret Module") then
        table.insert(compatibleSlots, "Turret Module")
    end
    if UIUtils.canEquipInSlot(itemId, "Defensive Module") then
        table.insert(compatibleSlots, "Defensive Module")
    end
    if UIUtils.canEquipInSlot(itemId, "Generator Module") then
        table.insert(compatibleSlots, "Generator Module")
    end
    return compatibleSlots
end

-- Check if context menu should be closed (clicked outside)
-- @param menu: context menu object (from ContextMenu.getMenu())
-- @param x, y: click coordinates
-- @return boolean: true if menu should be closed
function UIUtils.shouldCloseContextMenu(menu, x, y)
    if not menu then return false end
    local cmW = menu.width or 200
    local cmH = menu.height or ((menu.paddingY or 12) * 2 + (#menu.options * (menu.optionHeight or 24)))
    return not (x >= menu.x and x <= menu.x + cmW and y >= menu.y and y <= menu.y + cmH)
end

-- Create a hit test function for a window
-- @param window: window object with position, width, and height properties
-- @param getOpenFn: function that returns whether window is open
-- @return function: hit test function for use with registerInteractive
function UIUtils.createWindowHitTest(window, getOpenFn)
    -- Ensure getOpenFn properly binds self for method calls
    if not getOpenFn then
        if window and window.getOpen then
            -- Bind the method call to window so self is correctly set
            getOpenFn = function() return window:getOpen() end
        elseif window then
            getOpenFn = function() return window.isOpen end
        else
            getOpenFn = function() return false end
        end
    end
    return function(x, y, button)
        if not getOpenFn() or not window or not window.position then return false end
        return UIUtils.pointInRect(x, y, window.position.x, window.position.y, window.width, window.height)
    end
end

-- Create a click handler function for a window
-- @param window: window object with mousepressed method
-- @param windowName: name of the window for focus management
-- @param setWindowFocusFn: function to set window focus
-- @return function: click handler function for use with registerInteractive
function UIUtils.createWindowClickHandler(window, windowName, setWindowFocusFn)
    return function(x, y, button)
        if setWindowFocusFn and windowName then
            setWindowFocusFn(windowName)
        end
        if window and window.mousepressed then
            window:mousepressed(x, y, button)
        end
        return true
    end
end

-- Iterate over windows in focus order, calling a function on each
-- @param windows: table mapping window names to window objects
-- @param windowOrder: array of window names in focus order
-- @param callback: function(windowName, window) called for each window
-- @param reverse: if true, iterate in reverse order (most focused first)
-- @param filterFn: optional function(windowName, window) -> boolean to filter windows
function UIUtils.iterateWindows(windows, windowOrder, callback, reverse, filterFn)
    local order = reverse and #windowOrder or 1
    local step = reverse and -1 or 1
    local endIndex = reverse and 1 or #windowOrder
    
    -- Iterate windows in focus order
    for i = order, endIndex, step do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window and (not filterFn or filterFn(windowName, window)) then
            callback(windowName, window)
        end
    end
    
    -- Iterate windows not in focus order
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder and (not filterFn or filterFn(windowName, window)) then
            callback(windowName, window)
        end
    end
end

-- Slot component helper functions
-- These provide reusable access to equipment slot components

-- Get the item ID from a slot type on a drone
-- @param droneId: entity ID of the drone
-- @param slotType: "Turret Module", "Defensive Module", or "Generator Module"
-- @return itemId or nil if slot is empty or doesn't exist
function UIUtils.getSlotItem(droneId, slotType)
    local ECS = require('src.ecs')
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots and turretSlots.slots[1] then
            return turretSlots.slots[1]
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1] then
            return defensiveSlots.slots[1]
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots and generatorSlots.slots[1] then
            return generatorSlots.slots[1]
        end
    end
    return nil
end

-- Set the item ID in a slot type on a drone
-- @param droneId: entity ID of the drone
-- @param slotType: "Turret Module", "Defensive Module", or "Generator Module"
-- @param itemId: item ID to equip (nil to clear)
-- @return boolean: true if successful
function UIUtils.setSlotItem(droneId, slotType, itemId)
    local ECS = require('src.ecs')
    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots then
            turretSlots.slots[1] = itemId
            -- Also update the Turret component moduleName
            local turret = ECS.getComponent(droneId, "Turret")
            if turret then
                turret.moduleName = itemId
            end
            return true
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots and defensiveSlots.slots then
            defensiveSlots.slots[1] = itemId
            return true
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots and generatorSlots.slots then
            generatorSlots.slots[1] = itemId
            return true
        end
    end
    return false
end

-- Check if a slot type is occupied on a drone
-- @param droneId: entity ID of the drone
-- @param slotType: "Turret Module", "Defensive Module", or "Generator Module"
-- @return boolean: true if slot is occupied
function UIUtils.isSlotOccupied(droneId, slotType)
    return UIUtils.getSlotItem(droneId, slotType) ~= nil
end

return UIUtils

