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
local Scaling = require('src.scaling')
local SettingsWindow = require('src.ui.settings_window')
local PauseMenu = require('src.ui.pause_menu')
local DeathOverlay = require('src.ui.death_overlay')
local Dialogs = require('src.ui.dialogs')
local ConstructionButton = require('src.ui.construction_button')
local HUDSystem = require('src.systems.hud')
local ContextMenu = require('src.ui.context_menu')
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

-- Map window
UISystem.registerInteractive('map_window', function(x, y, button)
    return MapWindow.isOpen and MapWindow.position and x >= MapWindow.position.x and x <= MapWindow.position.x + MapWindow.width
           and y >= MapWindow.position.y and y <= MapWindow.position.y + MapWindow.height
end, function(x, y, button)
    -- Map window captures input (no context menu for now)
    MapWindow:mousepressed(x, y, button)
    return true
end)

-- ShipWindow removed - use LoadoutWindow, CargoWindow, or SkillsWindow instead

-- Cargo window (standalone)
UISystem.registerInteractive('cargo_window', function(x, y, button)
    return CargoWindow:getOpen() and CargoWindow.position and x >= CargoWindow.position.x and x <= CargoWindow.position.x + CargoWindow.width
           and y >= CargoWindow.position.y and y <= CargoWindow.position.y + CargoWindow.height
end, function(x, y, button)
    UISystem.setWindowFocus('cargo_window')
    if CargoWindow.mousepressed then CargoWindow:mousepressed(x, y, button) end
    return true
end)

-- Loadout window (standalone)
UISystem.registerInteractive('loadout_window', function(x, y, button)
    return LoadoutWindow:getOpen() and LoadoutWindow.position and x >= LoadoutWindow.position.x and x <= LoadoutWindow.position.x + LoadoutWindow.width
           and y >= LoadoutWindow.position.y and y <= LoadoutWindow.position.y + LoadoutWindow.height
end, function(x, y, button)
    UISystem.setWindowFocus('loadout_window')
    if LoadoutWindow.mousepressed then LoadoutWindow:mousepressed(x, y, button) end
    return true
end)

-- Skills window (standalone)
UISystem.registerInteractive('skills_window', function(x, y, button)
    return SkillsWindow:getOpen() and SkillsWindow.position and x >= SkillsWindow.position.x and x <= SkillsWindow.position.x + SkillsWindow.width
           and y >= SkillsWindow.position.y and y <= SkillsWindow.position.y + SkillsWindow.height
end, function(x, y, button)
    UISystem.setWindowFocus('skills_window')
    if SkillsWindow.mousepressed then SkillsWindow:mousepressed(x, y, button) end
    return true
end)


-- Stats window
UISystem.registerInteractive('stats_window', function(x, y, button)
    return StatsWindow:getOpen() and StatsWindow.position and x >= StatsWindow.position.x and x <= StatsWindow.position.x + StatsWindow.width
           and y >= StatsWindow.position.y and y <= StatsWindow.position.y + StatsWindow.height
end, function(x, y, button)
    UISystem.setWindowFocus('stats_window')
    if StatsWindow.mousepressed then StatsWindow:mousepressed(x, y, button) end
    return true
end)


-- Quest window
UISystem.registerInteractive('quest_window', function(x, y, button)
    return QuestWindow.isOpen and QuestWindow.position and x >= QuestWindow.position.x and x <= QuestWindow.position.x + QuestWindow.width
           and y >= QuestWindow.position.y and y <= QuestWindow.position.y + QuestWindow.height
end, function(x, y, button)
    QuestWindow:mousepressed(x, y, button)
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
    
    -- Draw windows in focus order (background to foreground)
    local windows = {
        map_window = MapWindow,
        cargo_window = CargoWindow,
        loadout_window = LoadoutWindow,
        skills_window = SkillsWindow,
        stats_window = StatsWindow,
        quest_window = QuestWindow,
        settings_window = SettingsWindow
    }

    -- Draw windows in focus order (least focused first, most focused last)
    for _, windowName in ipairs(windowOrder) do
        local window = windows[windowName]
        if window and window:isVisible() then
            window:draw(viewportWidth, viewportHeight, uiMx, uiMy)
        end
    end

    -- Draw any windows not yet in the order (newly opened windows)
    for windowName, window in pairs(windows) do
        if not window:isVisible() then
            goto skip_window
        end

        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder then
            window:draw(viewportWidth, viewportHeight, uiMx, uiMy)
        end

        ::skip_window::
    end

    -- Draw pause menu overlay/panel after other windows so it appears on top
    PauseMenu:draw()

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
    
    -- Check for hovered items in priority order (CargoWindow first, then LoadoutWindow, then ShipWindow)
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
    MapWindow:update(dt)
    CargoWindow:update(dt)
    LoadoutWindow:update(dt)
    SkillsWindow:update(dt)
    StatsWindow:update(dt)
    QuestWindow:update(dt)
    SettingsWindow:update(dt)
    -- CargoWindow removed - now integrated into ShipWindow
end

-- Key pressed handler
function UISystem.keypressed(key)
    if PauseMenu:getOpen() then
        if PauseMenu:keypressed(key) then
            return true
        end
        return true
    end

    -- Check if CargoWindow, LoadoutWindow, or SkillsWindow want to consume input
    if CargoWindow:getOpen() then
        local consumed = CargoWindow:keypressed(key)
        if consumed then return true end
    end
    if LoadoutWindow:getOpen() then
        local consumed = LoadoutWindow:keypressed(key)
        if consumed then return true end
    end
    if SkillsWindow:getOpen() then
        local consumed = SkillsWindow:keypressed(key)
        if consumed then return true end
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
    local windows = {
        map_window = MapWindow,
        cargo_window = CargoWindow,
        loadout_window = LoadoutWindow,
        skills_window = SkillsWindow,
        stats_window = StatsWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window and window:getOpen() and window.mousereleased then
            window:mousereleased(mx, my, button)
        end
    end

    -- Forward to any windows not in the order - only if open
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder and window:getOpen() and window.mousereleased then
            window:mousereleased(mx, my, button)
        end
    end

    if SettingsWindow and SettingsWindow:getOpen() and SettingsWindow.mousereleased then
        SettingsWindow:mousereleased(mx, my, button)
    end

    -- Forward to quest window - only if open
    if QuestWindow and QuestWindow:getOpen() and QuestWindow.mousereleased then
        QuestWindow:mousereleased(mx, my, button)
    end

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
    local windows = {
        map_window = MapWindow,
        ship_window = ShipWindow,
        cargo_window = CargoWindow,
        loadout_window = LoadoutWindow,
        skills_window = SkillsWindow,
        stats_window = StatsWindow,
        quest_window = QuestWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window and window:getOpen() and window.mousemoved then
            window:mousemoved(mx, my, dx, dy)
        end
    end

    -- Forward to any windows not in the order - only if open
    for windowName, window in pairs(windows) do
        local inOrder = false
        for _, orderedName in ipairs(windowOrder) do
            if orderedName == windowName then
                inOrder = true
                break
            end
        end
        if not inOrder and window:getOpen() and window.mousemoved then
            window:mousemoved(mx, my, dx, dy)
        end
    end

    if SettingsWindow and SettingsWindow:getOpen() and SettingsWindow.mousemoved then
        SettingsWindow:mousemoved(mx, my, dx, dy)
    end

    -- Forward to quest window - only if open
    if QuestWindow and QuestWindow:getOpen() and QuestWindow.mousemoved then
        QuestWindow:mousemoved(mx, my, dx, dy)
    end

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
    local windows = {
        map_window = MapWindow,
        cargo_window = CargoWindow,
        loadout_window = LoadoutWindow,
        skills_window = SkillsWindow,
        stats_window = StatsWindow
    }

    for i = #windowOrder, 1, -1 do
        local windowName = windowOrder[i]
        local window = windows[windowName]
        if window and window:getOpen() and window.wheelmoved then
            if window:wheelmoved(x, y) then
                return true -- Consumed by window
            end
        end
    end

    if pauseOpen then
        return true
    end

    return false -- Not consumed
end

-- Public API functions
-- CargoWindow has been integrated into ShipWindow
function UISystem.setCargoWindowOpen(state)
    CargoWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('cargo_window')
    end
end

function UISystem.toggleCargoWindow()
    CargoWindow:setOpen(not CargoWindow.isOpen)
    if CargoWindow:getOpen() then
        UISystem.setWindowFocus('cargo_window')
    end
end

function UISystem.isCargoWindowOpen()
    return CargoWindow:getOpen()
end

function UISystem.setLoadoutWindowOpen(state)
    LoadoutWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('loadout_window')
    end
end

function UISystem.toggleLoadoutWindow()
    LoadoutWindow:setOpen(not LoadoutWindow.isOpen)
    if LoadoutWindow:getOpen() then
        UISystem.setWindowFocus('loadout_window')
    end
end

function UISystem.isLoadoutWindowOpen()
    return LoadoutWindow:getOpen()
end

function UISystem.setSkillsWindowOpen(state)
    SkillsWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('skills_window')
    end
end

function UISystem.toggleSkillsWindow()
    SkillsWindow:setOpen(not SkillsWindow.isOpen)
    if SkillsWindow:getOpen() then
        UISystem.setWindowFocus('skills_window')
    end
end

function UISystem.isSkillsWindowOpen()
    return SkillsWindow:getOpen()
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


-- Quest window functions
function UISystem.setQuestWindowOpen(state)
    QuestWindow:setOpen(state)
    if state then
        UISystem.setWindowFocus('quest_window')
    end
end

function UISystem.toggleQuestWindow()
    QuestWindow:toggle()
    if QuestWindow:getOpen() then
        UISystem.setWindowFocus('quest_window')
    end
end

function UISystem.isQuestWindowOpen()
    return QuestWindow:getOpen()
end

-- Skills panel is now integrated into ShipWindow
-- No separate API functions needed

-- ShipWindow removed - use individual windows instead

-- Public API for adding skill experience
function UISystem.addSkillExperience(skillName, xpGain)
    SkillUtils.addSkillExperience(skillName, xpGain)
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
    if CargoWindow and CargoWindow.onResize then CargoWindow:onResize(screenW, screenH) end
    if LoadoutWindow and LoadoutWindow.onResize then LoadoutWindow:onResize(screenW, screenH) end
    if SkillsWindow and SkillsWindow.onResize then SkillsWindow:onResize(screenW, screenH) end
    if QuestWindow and QuestWindow.onResize then QuestWindow:onResize(screenW, screenH) end
    if SettingsWindow and SettingsWindow.onResize then SettingsWindow:onResize(screenW, screenH) end
    if MapWindow and MapWindow.onResize then MapWindow:onResize(screenW, screenH) end
    if PauseMenu and PauseMenu.onResize then PauseMenu:onResize(screenW, screenH) end
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
