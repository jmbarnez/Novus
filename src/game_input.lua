---@diagnostic disable: undefined-global
-- Game Input Module
-- Handles all input events (keyboard, mouse, wheel)

local GameInput = {}

-- Dependencies
local HotkeyConfig = require('src.hotkey_config')
local Systems = require('src.systems')
local UISystem = require('src.systems.ui')

function GameInput.keypressed(key)
    -- If death overlay is visible, consume all key input so game/world cannot act
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        if UISystem and UISystem.keypressed then
            UISystem.keypressed(key)
        end
        return
    end

    -- Handle station/world interactions first (E key)
    if key == "e" or key == "return" then
        local WorldTooltipsSystem = Systems.WorldTooltipsSystem
        if WorldTooltipsSystem and WorldTooltipsSystem.handleKeyPress then
            WorldTooltipsSystem.handleKeyPress(key)
        end
    end

    local pauseHotkey = HotkeyConfig.getHotkey("settings_window")

    if key == pauseHotkey then
        if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
            UISystem.setPauseMenuOpen(false)
            return
        end

        if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
            UISystem.setSettingsWindowOpen(false)
            return
        elseif UISystem.isShipWindowOpen and UISystem.isShipWindowOpen() then
            UISystem.setShipWindowOpen(false)
            return
        elseif UISystem.isMapWindowOpen and UISystem.isMapWindowOpen() then
            UISystem.setMapWindowOpen(false)
            return
        elseif UISystem.isQuestWindowOpen and UISystem.isQuestWindowOpen() then
            UISystem.setQuestWindowOpen(false)
            return
        end

        UISystem.setPauseMenuOpen(true)
        return
    end

    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        if UISystem and UISystem.keypressed then
            UISystem.keypressed(key)
        end
        return
    end

    if key == HotkeyConfig.getHotkey("cargo_window") then
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
        local SettingsWindow = require('src.ui.settings_window')
        if SettingsWindow.keypressed then
            local handled = SettingsWindow:keypressed(key)
            if handled then
                return
            end
        end
        return
    end

    UISystem.keypressed = UISystem.keypressed or function(_) end
    UISystem.keypressed(key)
    Systems.InputSystem.keypressed(key)
end

function GameInput.mousepressed(x, y, button)
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        -- Let UI handle overlay clicks and consume them
        if UISystem and UISystem.mousepressed then
            UISystem.mousepressed(x, y, button)
        end
        return
    end
    if UISystem.mousepressed then
        local consumed = UISystem.mousepressed(x, y, button)
        if consumed then
            return
        end
    end
    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        return
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
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        return
    end
    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        return
    end
    Systems.InputSystem.keyreleased(key)
end

function GameInput.mousemoved(x, y, dx, dy, isTouch)
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        if UISystem and UISystem.mousemoved then
            UISystem.mousemoved(x, y, dx, dy, isTouch)
        end
        return
    end
    if UISystem.mousemoved then
        UISystem.mousemoved(x, y, dx, dy, isTouch)
    end
    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        return
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
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        if UISystem and UISystem.mousereleased then
            UISystem.mousereleased(x, y, button)
        end
        return
    end
    if UISystem.mousereleased then
        UISystem.mousereleased(x, y, button)
    end
    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        return
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
    local DeathOverlay = require('src.ui.death_overlay')
    if DeathOverlay and DeathOverlay.isVisible then
        if UISystem and UISystem.wheelmoved then
            UISystem.wheelmoved(x, y)
        end
        return
    end
    -- Forward to UI system first
    if UISystem.wheelmoved then
        local consumed = UISystem.wheelmoved(x, y)
        if consumed then
            return
        end
    end
    if UISystem.isPauseMenuOpen and UISystem.isPauseMenuOpen() then
        return
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

