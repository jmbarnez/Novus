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

return UIUtils

