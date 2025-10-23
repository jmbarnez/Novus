---@diagnostic disable: undefined-global
-- Game Input Module
-- Handles all input events (keyboard, mouse, wheel)

local GameInput = {}

-- Dependencies
local HotkeyConfig = require('src.hotkey_config')
local Systems = require('src.systems')
local UISystem = require('src.systems.ui')

function GameInput.keypressed(key)
    -- If a window is currently open, let UISystem handle closing it first
    if key == HotkeyConfig.getHotkey("settings_window") then
        if UISystem.isShipWindowOpen and UISystem.isShipWindowOpen() then
            UISystem.setShipWindowOpen(false)
            return
        elseif UISystem.isMapWindowOpen and UISystem.isMapWindowOpen() then
            UISystem.setMapWindowOpen(false)
            return
        elseif UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
            UISystem.setSettingsWindowOpen(false)
            return
        end
        -- Otherwise, open the settings window
        UISystem.toggleSettingsWindow()
        return
    elseif key == HotkeyConfig.getHotkey("cargo_window") then
        UISystem.toggleShipWindow()
        return
    elseif key == HotkeyConfig.getHotkey("toggle_hud") then
        local HUDSystem = require('src.systems.hud')
        if HUDSystem and HUDSystem.toggle then
            HUDSystem.toggle()
        end
        return
    end
    
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        -- Forward key event directly to settings window and DO NOT propagate to global handlers
        local SettingsWindow = require('src.ui.settings_window')
        if SettingsWindow.keypressed then
            local handled = SettingsWindow:keypressed(key)
            if handled then
                return
            end
        end
        -- If settings window did not handle the key (but is open), consume the key anyway
        return
    end
    
    UISystem.keypressed = UISystem.keypressed or function(_) end
    UISystem.keypressed(key)
    Systems.InputSystem.keypressed(key)
end

function GameInput.mousepressed(x, y, button)
    print("Core.mousepressed called", x, y, button)
    if UISystem.mousepressed then
        local consumed = UISystem.mousepressed(x, y, button)
        if consumed then
            return
        end
    end
    -- If settings window is open, consume mouse input to avoid interacting with the world
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        return
    end
    if Systems.InputSystem.mousepressed then
        Systems.InputSystem.mousepressed(x, y, button)
    end
end

function GameInput.keyreleased(key)
    Systems.InputSystem.keyreleased(key)
end

function GameInput.mousemoved(x, y, dx, dy, isTouch)
    if UISystem.mousemoved then
        UISystem.mousemoved(x, y, dx, dy, isTouch)
    end
    -- If settings window is open, do not forward mouse move to the game systems
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        return
    end
    if Systems.InputSystem.mousemoved then
        Systems.InputSystem.mousemoved(x, y, dx, dy, isTouch)
    end
end

function GameInput.mousereleased(x, y, button)
    if UISystem.mousereleased then
        UISystem.mousereleased(x, y, button)
    end
    -- If settings window is open, consume mouse release events
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        return
    end
    if Systems.InputSystem.mousereleased then
        Systems.InputSystem.mousereleased(x, y, button)
    end
end

function GameInput.wheelmoved(x, y)
    -- Forward to UI system first
    if UISystem.wheelmoved then
        local consumed = UISystem.wheelmoved(x, y)
        if consumed then
            return
        end
    end
    -- If settings window is open, do not forward wheel to game systems
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        return
    end
    -- Forward to input system for camera zoom only if not consumed by UI
    if Systems.InputSystem.wheelmoved then
        Systems.InputSystem.wheelmoved(x, y)
    end
end

return GameInput

