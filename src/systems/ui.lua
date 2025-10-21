---@diagnostic disable: undefined-global
-- UI System - Main UI coordinator with modular components
-- Uses theme system and modular components for clean organization

local ECS = require('src.ecs')
local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local MapWindow = require('src.ui.map_window')
local ShipWindow = require('src.ui.ship_window')
local Tooltips = require('src.ui.tooltips')
local Dialogs = require('src.ui.dialogs')
local Notifications = require('src.ui.notifications')
local SkillNotifications = require('src.ui.skill_notifications')
local Scaling = require('src.scaling')
local SettingsWindow = require('src.ui.settings_window')
-- Hotbar removed
-- CargoWindow removed - now integrated into ShipWindow
-- SkillsWindow removed - now a panel within ShipWindow

-- UI System main table
local UISystem = {
    name = "UISystem",
    priority = 10
}

-- Track whether the UI has captured (consumed) pointer input
local mouseCaptured = false

function UISystem.captureMouse()
    mouseCaptured = true
end

function UISystem.releaseMouse()
    mouseCaptured = false
end

function UISystem.isMouseCaptured()
    return mouseCaptured
end

-- Window focus management
local focusedWindow = nil
local windowOrder = {} -- Array of window names in focus order (last focused is at the end)

function UISystem.setWindowFocus(windowName)
    if focusedWindow ~= windowName then
        focusedWindow = windowName
        -- Move this window to the end of the order (top)
        for i, name in ipairs(windowOrder) do
            if name == windowName then
                table.remove(windowOrder, i)
                break
            end
        end
        table.insert(windowOrder, windowName)
    end
end

function UISystem.getFocusedWindow()
    return focusedWindow
end

function UISystem.getWindowOrder()
    return windowOrder
end

-- Interactive registry for UI elements that should capture pointer input
local interactiveOrder = {}
local interactiveMap = {}

-- Register an interactive area with a hit-test and optional click handler
-- name (string), hitTestFn(x,y,button) -> boolean, clickHandlerFn(x,y,button) -> boolean
-- Note: hitTestFn and clickHandlerFn receive scaled coordinates (reference space)
function UISystem.registerInteractive(name, hitTestFn, clickHandlerFn)
    if interactiveMap[name] then
        -- replace existing
        interactiveMap[name] = {hit = hitTestFn, handler = clickHandlerFn}
        return
    end
    interactiveMap[name] = {hit = hitTestFn, handler = clickHandlerFn}
    table.insert(interactiveOrder, name)
end

function UISystem.unregisterInteractive(name)
    interactiveMap[name] = nil
    for i, n in ipairs(interactiveOrder) do
        if n == name then
            table.remove(interactiveOrder, i)
            break
        end
    end
end

-- Register default interactive elements
-- Confirmation dialog
UISystem.registerInteractive('confirm_dialog', function(x, y, button)
    return Dialogs.confirmDialog ~= nil and true or false
end, function(x, y, button)
    return Dialogs.handleConfirmDialogClick(x, y, button)
end)


-- Cargo and Skills windows are now integrated into ShipWindow as panels

-- Map window
UISystem.registerInteractive('map_window', function(x, y, button)
    return MapWindow.isOpen and MapWindow.position and x >= MapWindow.position.x and x <= MapWindow.position.x + MapWindow.width
           and y >= MapWindow.position.y and y <= MapWindow.position.y + MapWindow.height
end, function(x, y, button)
    -- Map window captures input (no context menu for now)
    MapWindow:mousepressed(x, y, button)
    return true
end)

-- Ship window (contains loadout, inventory, and skills panels)
UISystem.registerInteractive('ship_window', function(x, y, button)
    return ShipWindow.isOpen and ShipWindow.position and x >= ShipWindow.position.x and x <= ShipWindow.position.x + ShipWindow.width
           and y >= ShipWindow.position.y and y <= ShipWindow.position.y + ShipWindow.height
end, function(x, y, button)
    ShipWindow:mousepressed(x, y, button)
    return true
end)

-- Ship window (contains loadout, inventory, and skills panels)
-- Ship window integration removed; handled by ShipWindow module itself if needed

-- Register settings window
UISystem.registerInteractive('settings_window', function(x, y, button)
    return SettingsWindow.isOpen and SettingsWindow.position and x >= SettingsWindow.position.x and x <= SettingsWindow.position.x + SettingsWindow.width
           and y >= SettingsWindow.position.y and y <= SettingsWindow.position.y + SettingsWindow.height
end, function(x, y, button)
    SettingsWindow:mousepressed(x, y, button)
    return true
end)

-- Minimap input capture is now handled by HUD, but we still want UI to eat clicks over minimap
local Minimap = require('src.systems.minimap')
UISystem.registerInteractive('minimap', function(x, y, button)
    return Minimap and Minimap.isPointOver and Minimap.isPointOver(x, y)
end, function(x, y, button)
    -- just consume the click
    return true
end)

-- HUD drawing has been moved to `src.systems.hud`

-- Main draw function
function UISystem.draw(viewportWidth, viewportHeight)
    -- Get viewport dimensions from parameters or canvas
    if not viewportWidth or not viewportHeight then
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        viewportWidth = Constants.screen_width
        viewportHeight = Constants.screen_height
        
        if #canvasEntities > 0 then
            local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
            if canvasComp then
                viewportWidth = canvasComp.width
                viewportHeight = canvasComp.height
            end
        end
    end
    -- viewportWidth/viewportHeight are already canvas (reference) units
    
    -- HUD elements are rendered by the HUD system inside RenderSystem
    
    -- Draw notifications (in screen space)
    Notifications.draw(0, 0, 1)
    
    -- Draw skill notifications (in screen space)
    SkillNotifications.draw()
    
    -- Draw windows in focus order (background to foreground)
    local windows = {
        map_window = MapWindow,
        ship_window = ShipWindow,
        settings_window = SettingsWindow
    }

    -- Draw windows in focus order (least focused first, most focused last)
    for _, windowName in ipairs(windowOrder) do
        local window = windows[windowName]
        if window then
            window:draw(viewportWidth, viewportHeight)
        end
    end

    -- Draw any windows not yet in the order (newly opened windows)
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder then
            window:draw(viewportWidth, viewportHeight)
        end
    end
    
    -- Draw confirmation dialog if active (highest priority)
    if Dialogs.confirmDialog then
        Dialogs.drawConfirmDialog()
    end
    
    -- Draw tooltip if hovering over item and no menus are open
    if ShipWindow.isOpen and ShipWindow.hoveredItemSlot and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            ShipWindow.hoveredItemSlot.itemId,
            ShipWindow.hoveredItemSlot.itemDef,
            ShipWindow.hoveredItemSlot.count,
            ShipWindow.hoveredItemSlot.mouseX,
            ShipWindow.hoveredItemSlot.mouseY
        )
        -- Not handled by UI
        return false
    end

    -- Draw tooltip for ship window turret slot
    if ShipWindow.isOpen and ShipWindow.hoveredTurretSlot and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            ShipWindow.hoveredTurretSlot.itemId,
            ShipWindow.hoveredTurretSlot.itemDef,
            ShipWindow.hoveredTurretSlot.count,
            ShipWindow.hoveredTurretSlot.mouseX,
            ShipWindow.hoveredTurretSlot.mouseY
        )
        return false
    end

    -- Draw tooltip for ship window defensive slot
    if ShipWindow.isOpen and ShipWindow.hoveredDefensiveSlot and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            ShipWindow.hoveredDefensiveSlot.itemId,
            ShipWindow.hoveredDefensiveSlot.itemDef,
            ShipWindow.hoveredDefensiveSlot.count,
            ShipWindow.hoveredDefensiveSlot.mouseX,
            ShipWindow.hoveredDefensiveSlot.mouseY
        )
        return false
    end

    -- Draw tooltip for ship window available modules
    if ShipWindow.isOpen and ShipWindow.hoveredItemSlot and not Dialogs.confirmDialog then
        Tooltips.drawItemTooltip(
            ShipWindow.hoveredItemSlot.itemId,
            ShipWindow.hoveredItemSlot.itemDef,
            ShipWindow.hoveredItemSlot.count,
            ShipWindow.hoveredItemSlot.mouseX,
            ShipWindow.hoveredItemSlot.mouseY
        )
        return false
    end

    return false
end

-- Update function for UI (handles notifications timing)
function UISystem.update(dt)
    Notifications.update(dt)
    SkillNotifications.update(dt)
    -- CargoWindow removed - now integrated into ShipWindow
end

-- Key pressed handler
function UISystem.keypressed(key)
    -- Tab key is now handled in core.lua to toggle ShipWindow
    local HotkeyConfig = require('src.hotkey_config')
    if key == HotkeyConfig.getHotkey("settings_window") then
        if SettingsWindow:getOpen() then
            SettingsWindow:setOpen(false)
            return
        end
        if ShipWindow:getOpen() then
            ShipWindow:setOpen(false)
            return
        end
        if MapWindow:getOpen() then
            MapWindow:setOpen(false)
            return
        end
        -- If no windows open, open settings window
        SettingsWindow:setOpen(true)
        UISystem.setWindowFocus('settings_window')
        return
    end
    if key == HotkeyConfig.getHotkey("map_window") then
        MapWindow:toggle()
        if MapWindow:getOpen() then
            UISystem.setWindowFocus('map_window')
        end
    end
end

-- Mouse pressed handler
function UISystem.mousepressed(x, y, button)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)

    -- Check focused window first (if it exists and is open)
    if focusedWindow and interactiveMap[focusedWindow] then
        local entry = interactiveMap[focusedWindow]
        if entry and entry.hit and entry.hit(mx, my, button) then
            local handled = false
            if entry.handler then handled = entry.handler(mx, my, button) end
            if handled then
                -- Keep the focused window focused
                UISystem.captureMouse()
                return true
            end
        end
    end

    -- Check other windows in focus order (most recently focused first)
    for i = #windowOrder, 1, -1 do
        local name = windowOrder[i]
        -- Skip the focused window since we already checked it
        if name ~= focusedWindow and interactiveMap[name] then
            local entry = interactiveMap[name]
            if entry and entry.hit and entry.hit(mx, my, button) then
                -- Set this window as focused when clicked
                UISystem.setWindowFocus(name)
                local handled = false
                if entry.handler then handled = entry.handler(mx, my, button) end
                if handled then
                    UISystem.captureMouse()
                    return true
                end
            end
        end
    end

    -- Check remaining interactive elements (non-windows) in registration order
    for _, name in ipairs(interactiveOrder) do
        -- Skip windows since we already handled them above
        if not (name == 'cargo_window' or name == 'map_window' or name == 'ship_window') then
            local entry = interactiveMap[name]
            if entry and entry.hit and entry.hit(mx, my, button) then
                local handled = false
                if entry.handler then handled = entry.handler(mx, my, button) end
                if handled then
                    UISystem.captureMouse()
                    return true
                end
            end
        end
    end

    -- Also pass to settings window if it's open
    if SettingsWindow and SettingsWindow.isOpen and SettingsWindow.mousepressed then
        local mx, my = Scaling.toUI(x, y)
        if mx >= SettingsWindow.position.x and mx <= SettingsWindow.position.x + SettingsWindow.width and
           my >= SettingsWindow.position.y and my <= SettingsWindow.position.y + SettingsWindow.height then
            SettingsWindow:mousepressed(mx, my, button)
            UISystem.setWindowFocus('settings_window')
            return true
        end
    end

    -- If click is on the minimap, capture it so it doesn't pass to the world
    local Minimap = require('src.systems.minimap')
    if Minimap and Minimap.isPointOver then
        if Minimap.isPointOver(mx, my) then
            UISystem.captureMouse()
            return true
        end
    end
end

-- Mouse released handler
function UISystem.mousereleased(x, y, button)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)

    -- Forward to windows in focus order (most focused first)
    local windows = {
        map_window = MapWindow,
        ship_window = ShipWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window then
            window:mousereleased(mx, my, button)
        end
    end

    -- Forward to any windows not in the order
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder then
            window:mousereleased(mx, my, button)
        end
    end

    if SettingsWindow and SettingsWindow.isOpen and SettingsWindow.mousereleased then
        local mx, my = Scaling.toUI(x, y)
        SettingsWindow:mousereleased(mx, my, button)
    end

    -- Release capture on mouse release (assumes left click)
    if button == 1 then
        UISystem.releaseMouse()
    end
end

-- Mouse moved handler
function UISystem.mousemoved(x, y, dx, dy, isTouch)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale)
    local mx, my = Scaling.toUI(x, y)

    -- Forward to windows in focus order (most focused first)
    local windows = {
        map_window = MapWindow,
        ship_window = ShipWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window then
            window:mousemoved(mx, my, dx, dy)
        end
    end

    -- Forward to any windows not in the order
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder then
            window:mousemoved(mx, my, dx, dy)
        end
    end

    if SettingsWindow and SettingsWindow.isOpen and SettingsWindow.mousemoved then
        local mx, my = Scaling.toUI(x, y)
        SettingsWindow:mousemoved(mx, my, dx, dy)
    end
end

-- Mouse wheel handler
function UISystem.wheelmoved(x, y)
    -- Forward to settings window first if open
    if SettingsWindow and SettingsWindow:getOpen() and SettingsWindow.wheelmoved then
        if SettingsWindow:wheelmoved(x, y) then
            return true -- Consumed by settings window
        end
    end
    
    -- Forward to other windows
    local windows = {
        map_window = MapWindow,
        ship_window = ShipWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window and window.wheelmoved then
            if window:wheelmoved(x, y) then
                return true -- Consumed by window
            end
        end
    end
    
    return false -- Not consumed
end

-- Public API functions
-- CargoWindow has been integrated into ShipWindow
-- For backwards compatibility, cargo functions now control ShipWindow
function UISystem.setCargoWindowOpen(state)
    ShipWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('ship_window')
    end
end

function UISystem.toggleCargoWindow()
    ShipWindow:toggle()
    if ShipWindow:getOpen() then
        UISystem.setWindowFocus('ship_window')
    end
end

function UISystem.isCargoWindowOpen()
    return ShipWindow:getOpen()
end

function UISystem.setMapWindowOpen(state)
    MapWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('map_window')
    end
end

function UISystem.toggleMapWindow()
    MapWindow:toggle()
    if MapWindow:getOpen() then
        UISystem.setWindowFocus('map_window')
    end
end

function UISystem.isMapWindowOpen()
    return MapWindow:getOpen()
end

-- Skills panel is now integrated into ShipWindow
-- No separate API functions needed

function UISystem.setShipWindowOpen(state)
    ShipWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('ship_window')
    end
end

function UISystem.toggleShipWindow()
    ShipWindow:toggle()
    if ShipWindow:getOpen() then
        UISystem.setWindowFocus('ship_window')
    end
end

function UISystem.isShipWindowOpen()
    return ShipWindow:getOpen()
end

-- Public API for adding skill experience
function UISystem.addSkillExperience(skillName, xpGain)
    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #playerEntities == 0 then return end
    
    local playerId = playerEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills or not skills.skills[skillName] then return end
    
    local skill = skills.skills[skillName]
    skill.experience = skill.experience + xpGain
    skill.totalXp = skill.totalXp + xpGain
    
    -- Check for level up
    local leveledUp = false
    while skill.experience >= skill.requiredXp do
        skill.experience = skill.experience - skill.requiredXp
        skill.level = skill.level + 1
        skill.requiredXp = math.ceil(skill.requiredXp * 1.1)  -- 10% increase per level
        leveledUp = true
    end
    
    -- Show notification
    local notifData = {
        level = skill.level,
        experience = skill.experience,
        requiredXp = skill.requiredXp,
        levelUp = leveledUp
    }
    SkillNotifications.addNotification(skillName, xpGain, notifData)
end

-- Settings Window API
function UISystem.setSettingsWindowOpen(state)
    SettingsWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('settings_window')
    end
end
function UISystem.toggleSettingsWindow()
    SettingsWindow:toggle()
    if SettingsWindow:getOpen() then
        UISystem.setWindowFocus('settings_window')
    end
end
function UISystem.isSettingsWindowOpen()
    return SettingsWindow:getOpen()
end

return UISystem
