---@diagnostic disable: undefined-global
-- UI System - Main UI coordinator with modular components
-- Uses theme system and modular components for clean organization

local ECS = require('src.ecs')
local Constants = require('src.constants')
local SkillUtils = require('src.skill_utils')
local Theme = require('src.ui.plasma_theme')
local MapWindow = require('src.ui.map_window')
-- ShipWindow removed - use LoadoutWindow, CargoWindow, or SkillsWindow instead
local StatsWindow = require('src.ui.stats_window')
local CargoWindow = require('src.ui.cargo_window')
local LoadoutWindow = require('src.ui.loadout_window')
local SkillsWindow = require('src.ui/skills_window')
local QuestWindow = require('src.ui.quest_window')
local Tooltips = require('src.ui.tooltips')
local Notifications = require('src.ui.notifications')
local ShopWindow = require('src.ui.shop_window')
local StationWindow = require('src.ui.station_window')
local Scaling = require('src.scaling')
local SettingsWindow = require('src.ui.settings_window')
local PauseMenu = require('src.ui.pause_menu')
local DeathOverlay = require('src.ui.death_overlay')
local Dialogs = require('src.ui.dialogs')
local ConstructionButton = require('src.ui.construction_button')
local HUDSystem = require('src.systems.hud')
local ContextMenu = require('src.ui.context_menu')
local UIUtils = require('src.ui.ui_utils')
-- QuestOverlay moved to HUD system for batched rendering
-- Hotbar removed
-- CargoWindow removed - now integrated into ShipWindow
-- SkillsWindow removed - now a panel within ShipWindow

-- UI System main table
local UISystem = {
    name = "UISystem",
    priority = 10
}

-- UI draw throttle: limit UI draws to this interval (seconds)
local ui_last_draw = 0
local ui_draw_interval = 1 / 60 -- 60 FPS

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



-- Cargo and Skills windows were previously integrated into ShipWindow as panels.
-- They are now available as independent windows (`CargoWindow`, `SkillsWindow`) and
-- can be opened directly. ShipWindow still embeds panels for tabbed mode.

-- Helper function to register a standard window with consistent behavior
local function registerWindow(name, window, useFocus)
    -- Create a properly bound getOpen function
    local getOpenFn
    if window.getOpen then
        -- Bind method call to window so self is correctly set
        getOpenFn = function() return window:getOpen() end
    else
        getOpenFn = function() return window.isOpen end
    end
    
    local hitTest = UIUtils.createWindowHitTest(window, getOpenFn)
    local clickHandler = useFocus 
        and UIUtils.createWindowClickHandler(window, name, UISystem.setWindowFocus)
        or (function(x, y, button)
            if window.mousepressed then window:mousepressed(x, y, button) end
            return true
        end)
    UISystem.registerInteractive(name, hitTest, clickHandler)
end

-- Central windows registry for iteration
local windows = {
    map_window = MapWindow,
    cargo_window = CargoWindow,
    loadout_window = LoadoutWindow,
    skills_window = SkillsWindow,
    stats_window = StatsWindow,
    quest_window = QuestWindow,
    shop_window = ShopWindow,
    station_window = StationWindow,
    settings_window = SettingsWindow
}

-- Register windows using helper function
registerWindow('map_window', MapWindow, false)  -- Map window doesn't use focus system
registerWindow('cargo_window', CargoWindow, true)
registerWindow('loadout_window', LoadoutWindow, true)
registerWindow('skills_window', SkillsWindow, true)
registerWindow('stats_window', StatsWindow, true)
registerWindow('quest_window', QuestWindow, false)  -- Quest window doesn't use focus system
registerWindow('settings_window', SettingsWindow, false)  -- Settings window doesn't use focus system
registerWindow('shop_window', ShopWindow, true)
registerWindow('station_window', StationWindow, true)

-- Minimap input capture is now handled by HUD, but we still want UI to eat clicks over minimap
local Minimap = require('src.systems.hud.minimap')
UISystem.registerInteractive('minimap', function(x, y, button)
    return Minimap and Minimap.isPointOver and Minimap.isPointOver(x, y)
end, function(x, y, button)
    -- just consume the click
    return true
end)

-- HUD drawing has been moved to `src.systems.hud`

-- Main draw function
function UISystem.draw(viewportWidth, viewportHeight, uiMx, uiMy)
    -- Get viewport dimensions from parameters or canvas
    if not viewportWidth or not viewportHeight then
        local canvasEntities = ECS.getEntitiesWith({"Canvas"})
        viewportWidth = Constants.getScreenWidth()
        viewportHeight = Constants.getScreenHeight()
        
        if #canvasEntities > 0 then
            local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
            if canvasComp then
                viewportWidth = canvasComp.width
                viewportHeight = canvasComp.height
            end
        end
    end
    -- viewportWidth/viewportHeight are already canvas (reference) units
    -- UI throttling removed to fix flickering issue
    -- local now = love.timer.getTime()
    -- if now - ui_last_draw < ui_draw_interval then
    --     return false
    -- end
    -- ui_last_draw = now
    
    -- HUD elements are rendered by the HUD system inside RenderSystem
    
    -- Draw notifications (in screen space)
    Notifications.draw()
    
    -- Draw skill notifications (in screen space)
    -- SkillNotifications.draw() -- REMOVE THIS
    
    -- Quest overlay moved to HUD system for batched rendering
    
    -- Check if pause menu is open - if so, draw overlay and panel first (before windows)
    -- Windows opened from pause menu (like settings) should render on top
    local pauseOpen = PauseMenu:getOpen()
    if pauseOpen then
        -- Draw pause menu overlay background (dims the screen) before everything
        PauseMenu:drawOverlay()
        -- Draw pause menu panel before windows so focused windows appear on top
        PauseMenu:_drawPanelOnly()
    end
    
    -- Draw windows in focus order (least focused first, most focused last)
    -- Windows opened from pause menu will appear on top of the pause overlay and panel
    UIUtils.iterateWindows(windows, windowOrder, function(windowName, window)
        if window:isVisible() then
            window:draw(viewportWidth, viewportHeight, uiMx, uiMy)
        end
    end, false, function(windowName, window)
        return window:isVisible()
    end)

    -- Draw confirmation dialog if active (highest priority - appears above pause menu)
    if Dialogs.confirmDialog then
        Dialogs.drawConfirmDialog()
    end

    if PauseMenu:getOpen() then
        return true
    end

    -- Draw tooltip for hovered slots (check both ShipWindow and CargoWindow)
    if Dialogs.confirmDialog then
        return false
    end
    
    -- Check for hovered items in priority order (CargoWindow first, then LoadoutWindow, then StationWindow shop)
    local hoveredSlot = nil
    local hoveredEquipmentSlot = nil
    local contextMenuOpen = false
    local mouseX, mouseY
    
    -- Get current mouse position in UI space for tooltips
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mouseX, mouseY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mouseX, mouseY = Scaling.toUI(love.mouse.getPosition())
    end
    
    if CargoWindow:getOpen() then
        hoveredSlot = CargoWindow.hoveredItemSlot
        contextMenuOpen = ContextMenu.isOpen()
    end
    
    if not hoveredSlot and LoadoutWindow:getOpen() then
        -- Check for hovered equipment slot
        if LoadoutWindow.hoveredEquipmentSlot and LoadoutWindow.hoveredEquipmentSlot.itemId then
            hoveredEquipmentSlot = LoadoutWindow.hoveredEquipmentSlot
        end
        contextMenuOpen = ContextMenu.isOpen()
    end
    
    if not hoveredSlot and not hoveredEquipmentSlot and StationWindow:getOpen() and StationWindow.activeTab == "shop" then
        -- Check for hovered shop item
        if StationWindow.hoveredItemSlot and StationWindow.hoveredItemSlot.itemId then
            hoveredSlot = StationWindow.hoveredItemSlot
        end
    end
    

    -- Draw tooltip for cargo/item slots
    if hoveredSlot and not contextMenuOpen then
        Tooltips.drawItemTooltip(
            hoveredSlot.itemId,
            hoveredSlot.itemDef,
            hoveredSlot.count,
            hoveredSlot.mouseX,
            hoveredSlot.mouseY
        )
    -- Draw tooltip for equipment slots
    elseif hoveredEquipmentSlot and not contextMenuOpen then
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[hoveredEquipmentSlot.itemId]
        if itemDef then
            Tooltips.drawItemTooltip(
                hoveredEquipmentSlot.itemId,
                itemDef,
                1, -- count is always 1 for equipped items
                mouseX,
                mouseY
            )
        end
    end

    -- Remove or comment out:
    -- ConstructionButton.draw(viewportWidth, viewportHeight)

    return false
end

-- Update function for UI (handles notifications timing)
function UISystem.update(dt)
    Notifications.update(dt)
    PauseMenu:update(dt)
    
    -- Update all windows
    for windowName, window in pairs(windows) do
        if window and window.update then
            window:update(dt)
        end
    end
end

-- Key pressed handler
function UISystem.keypressed(key)
    if PauseMenu:getOpen() then
        if PauseMenu:keypressed(key) then
            return true
        end
        return true
    end

    -- Check if any open window wants to consume input
    for windowName, window in pairs(windows) do
        if window:getOpen() and window.keypressed then
            local consumed = window:keypressed(key)
            if consumed then return true end
        end
    end

    -- Tab key is now handled in core.lua to toggle ShipWindow
    local HotkeyConfig = require('src.hotkey_config')
    if key == HotkeyConfig.getHotkey("settings_window") then
        if SettingsWindow:getOpen() then
            SettingsWindow:setOpen(false)
            return true
        end
        if MapWindow:getOpen() then
            MapWindow:setOpen(false)
            return true
        end
        if QuestWindow:getOpen() then
            QuestWindow:setOpen(false)
            return true
        end
        -- If no windows open, open settings window
        SettingsWindow:setOpen(true)
        UISystem.setWindowFocus('settings_window')
        return true
    end
    if key == HotkeyConfig.getHotkey("map_window") then
        MapWindow:toggle()
        if MapWindow:getOpen() then
            UISystem.setWindowFocus('map_window')
        end
        return true
    end
    return false
end

-- Mouse pressed handler
function UISystem.mousepressed(x, y, button)
    -- Death overlay blocks all other UI when visible
    if DeathOverlay and DeathOverlay.isVisible then
        DeathOverlay.mousepressed(x, y, button)
        UISystem.captureMouse()
        return true
    end
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale) - ONCE
    local mx, my = Scaling.toUI(x, y)

    local pauseOpen = PauseMenu:getOpen()
    if pauseOpen then
        local handled = PauseMenu:mousepressed(mx, my, button)
        if handled then
            UISystem.captureMouse()
            return true
        end
    end
    -- Check construction button (screen-space, not UI-space)
    if ConstructionButton.checkPressed(x, y, button) then
        UISystem.captureMouse()
        return true
    end

    if HUDSystem and HUDSystem.mousepressed and HUDSystem.mousepressed(x, y, button) then
        UISystem.captureMouse()
        return true
    end

    -- Check focused window first (if it exists and is open)
    if focusedWindow and interactiveMap[focusedWindow] then
        local entry = interactiveMap[focusedWindow]
        if entry and entry.hit and entry.hit(mx, my, button) then
            local handled = true
            if entry.handler then
                local handlerResult = entry.handler(mx, my, button)
                if handlerResult ~= nil then
                    handled = handlerResult
                end
            end
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
                local handled = true
                if entry.handler then
                    local handlerResult = entry.handler(mx, my, button)
                    if handlerResult ~= nil then
                        handled = handlerResult
                    end
                end
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
        if not (name == 'cargo_window' or name == 'map_window' or name == 'loadout_window' or name == 'skills_window') then
            local entry = interactiveMap[name]
            if entry and entry.hit and entry.hit(mx, my, button) then
                local handled = true
                if entry.handler then
                    local handlerResult = entry.handler(mx, my, button)
                    if handlerResult ~= nil then
                        handled = handlerResult
                    end
                end
                if handled then
                    UISystem.captureMouse()
                    return true
                end
            end
        end
    end

    -- Also pass to settings window if it's open
    if SettingsWindow and SettingsWindow.isOpen and SettingsWindow.mousepressed then
        if mx >= SettingsWindow.position.x and mx <= SettingsWindow.position.x + SettingsWindow.width and
           my >= SettingsWindow.position.y and my <= SettingsWindow.position.y + SettingsWindow.height then
            SettingsWindow:mousepressed(mx, my, button)
            UISystem.setWindowFocus('settings_window')
            UISystem.captureMouse()
            return true
        end
    end

    -- If click is on the minimap, capture it so it doesn't pass to the world
    local Minimap = require('src.systems.hud.minimap')
    if Minimap and Minimap.isPointOver then
        if Minimap.isPointOver(mx, my) then
            UISystem.captureMouse()
            return true
        end
    end

    if pauseOpen then
        UISystem.captureMouse()
        return true
    end

    return false
end

-- Mouse released handler
function UISystem.mousereleased(x, y, button)
    if HUDSystem and HUDSystem.mousereleased and HUDSystem.mousereleased(x, y, button) then
        if button == 1 then
            UISystem.releaseMouse()
        end
        return true
    end
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale) - ONCE
    local mx, my = Scaling.toUI(x, y)

    local pauseOpen = PauseMenu:getOpen()
    if pauseOpen then
        PauseMenu:mousereleased(mx, my, button)
    end

    -- Forward to windows in focus order (most focused first) - only if open
    UIUtils.iterateWindows(windows, windowOrder, function(windowName, window)
        if window.mousereleased then
            window:mousereleased(mx, my, button)
        end
    end, true, function(windowName, window)
        return window:getOpen() and window.mousereleased ~= nil
    end)

    -- Release capture on mouse release (assumes left click)
    if button == 1 then
        UISystem.releaseMouse()
    end

    if pauseOpen then
        return true
    end

    return false
end

-- Mouse moved handler
function UISystem.mousemoved(x, y, dx, dy, isTouch)
    -- Convert raw mouse coordinates to UI space (accounting for canvas offset and scale) - ONCE
    local mx, my = Scaling.toUI(x, y)

    if HUDSystem and HUDSystem.mousemoved then
        HUDSystem.mousemoved(x, y, dx, dy, isTouch)
    end

    local pauseOpen = PauseMenu:getOpen()
    if pauseOpen then
        PauseMenu:mousemoved(mx, my, dx, dy)
    end

    -- Forward to windows in focus order (most focused first) - only if open
    UIUtils.iterateWindows(windows, windowOrder, function(windowName, window)
        if window.mousemoved then
            window:mousemoved(mx, my, dx, dy)
        end
    end, true, function(windowName, window)
        return window:getOpen() and window.mousemoved ~= nil
    end)

    if pauseOpen then
        return
    end
end

-- Mouse wheel handler
function UISystem.wheelmoved(x, y)
    local pauseOpen = PauseMenu:getOpen()
    if pauseOpen then
        if PauseMenu:wheelmoved(x, y) then
            return true
        end
    end

    -- Forward to settings window first if open
    if SettingsWindow and SettingsWindow:getOpen() and SettingsWindow.wheelmoved then
        if SettingsWindow:wheelmoved(x, y) then
            return true -- Consumed by settings window
        end
    end

    -- Forward to other windows - only if open
    local consumed = false
    UIUtils.iterateWindows(windows, windowOrder, function(windowName, window)
        if window.wheelmoved then
            if window:wheelmoved(x, y) then
                consumed = true
            end
        end
    end, true, function(windowName, window)
        return window:getOpen() and window.wheelmoved ~= nil
    end)
    if consumed then
        return true
    end

    if pauseOpen then
        return true
    end

    return false -- Not consumed
end

-- Helper function to generate window API functions (setOpen, toggle, isOpen)
local function createWindowAPI(windowName, window, useFocus)
    local nameBase = windowName:gsub("_window", ""):gsub("_", "")
    local capName = nameBase:sub(1,1):upper() .. nameBase:sub(2)
    
    UISystem["set" .. capName .. "WindowOpen"] = function(state)
        window:setOpen(state)
        if state and useFocus then
            UISystem.setWindowFocus(windowName)
        end
    end
    
    UISystem["toggle" .. capName .. "Window"] = function()
        window:toggle()
        if window:getOpen() and useFocus then
            UISystem.setWindowFocus(windowName)
        end
    end
    
    UISystem["is" .. capName .. "WindowOpen"] = function()
        return window:getOpen()
    end
end

-- Generate API functions for windows
createWindowAPI('cargo_window', CargoWindow, true)
createWindowAPI('loadout_window', LoadoutWindow, true)
createWindowAPI('skills_window', SkillsWindow, true)
createWindowAPI('map_window', MapWindow, true)
createWindowAPI('quest_window', QuestWindow, false)  -- Quest window doesn't use focus system
createWindowAPI('settings_window', SettingsWindow, false)  -- Settings window doesn't use focus system
createWindowAPI('shop_window', ShopWindow, true)
createWindowAPI('station_window', StationWindow, true)

-- Public API for adding skill experience
function UISystem.addSkillExperience(skillName, xpGain)
    SkillUtils.addSkillExperience(skillName, xpGain)
end

-- Pause menu controls
function UISystem.setPauseMenuOpen(state)
    PauseMenu:setOpen(state)
end

function UISystem.togglePauseMenu()
    PauseMenu:toggle()
end

function UISystem.isPauseMenuOpen()
    return PauseMenu:getOpen()
end

function UISystem.onResize(screenW, screenH)
    screenW = screenW or love.graphics.getWidth()
    screenH = screenH or love.graphics.getHeight()
    
    -- Forward resize to all windows
    for windowName, window in pairs(windows) do
        if window and window.onResize then
            window:onResize(screenW, screenH)
        end
    end
    
    if PauseMenu and PauseMenu.onResize then
        PauseMenu:onResize(screenW, screenH)
    end
end

PauseMenu:setCallbacks({
    onVisibilityChanged = function(isOpen)
        if isOpen then
            UISystem.captureMouse()
        else
            UISystem.releaseMouse()
        end
    end,
    onRequestResume = function()
        UISystem.setPauseMenuOpen(false)
    end,
    onRequestSettings = function()
        UISystem.setPauseMenuOpen(false)
        UISystem.setSettingsWindowOpen(true)
    end,
    onRequestExit = function()
        UISystem.setPauseMenuOpen(false)
        local Game = rawget(_G, 'Game')
        if Game and Game.returnToMainMenu then
            Game.returnToMainMenu()
        end
    end
})

return UISystem

