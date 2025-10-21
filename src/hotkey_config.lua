---@diagnostic disable: undefined-global
-- Hotkey Configuration System
-- Manages customizable hotkeys for the game

local HotkeyConfig = {}

-- Default hotkey mappings
HotkeyConfig.defaults = {
    move_up = "w",
    move_down = "s", 
    move_left = "a",
    move_right = "d",
    target_enemy = "lctrl", -- Ctrl+Click
    cargo_window = "tab",
    skills_window = "v",
    ship_window = "g",
    toggle_hud = "f5",
    map_window = "m",
    settings_window = "escape"
}

-- Current hotkey mappings (loaded from defaults)
HotkeyConfig.current = {}

-- Hotkey descriptions for UI display
HotkeyConfig.descriptions = {
    move_up = "Move Up",
    move_down = "Move Down", 
    move_left = "Move Left",
    move_right = "Move Right",
    target_enemy = "Target Enemy (Ctrl+Click)",
    cargo_window = "Cargo Window",
    skills_window = "Skills Window",
    ship_window = "Ship Window",
    toggle_hud = "Toggle HUD",
    map_window = "Map Window",
    settings_window = "Settings Window"
}

-- Initialize hotkey configuration
function HotkeyConfig.init()
    -- Copy defaults to current (in a real game, you'd load from save file)
    for key, value in pairs(HotkeyConfig.defaults) do
        HotkeyConfig.current[key] = value
    end
end

-- Get current hotkey for an action
function HotkeyConfig.getHotkey(action)
    return HotkeyConfig.current[action] or HotkeyConfig.defaults[action]
end

-- Set hotkey for an action
function HotkeyConfig.setHotkey(action, key)
    if HotkeyConfig.descriptions[action] then
        HotkeyConfig.current[action] = key
        return true
    end
    return false
end

-- Get all configurable hotkeys
function HotkeyConfig.getAllHotkeys()
    local hotkeys = {}
    for action, description in pairs(HotkeyConfig.descriptions) do
        table.insert(hotkeys, {
            action = action,
            description = description,
            key = HotkeyConfig.getHotkey(action)
        })
    end
    return hotkeys
end

-- Reset all hotkeys to defaults
function HotkeyConfig.resetToDefaults()
    for key, value in pairs(HotkeyConfig.defaults) do
        HotkeyConfig.current[key] = value
    end
end

-- Check if a key is currently mapped to any action
function HotkeyConfig.isKeyMapped(key)
    for _, mappedKey in pairs(HotkeyConfig.current) do
        if mappedKey == key then
            return true
        end
    end
    return false
end

-- Get action for a key
function HotkeyConfig.getActionForKey(key)
    for action, mappedKey in pairs(HotkeyConfig.current) do
        if mappedKey == key then
            return action
        end
    end
    return nil
end

-- Format key for display (handles special keys)
function HotkeyConfig.formatKey(key)
    local keyMap = {
        ["lctrl"] = "Ctrl",
        ["rctrl"] = "Ctrl",
        ["lshift"] = "Shift", 
        ["rshift"] = "Shift",
        ["lalt"] = "Alt",
        ["ralt"] = "Alt",
        ["escape"] = "Esc",
        ["return"] = "Enter",
        ["space"] = "Space",
        ["backspace"] = "Backspace",
        ["tab"] = "Tab",
        ["up"] = "↑",
        ["down"] = "↓", 
        ["left"] = "←",
        ["right"] = "→"
    }
    
    return keyMap[key] or string.upper(key)
end

-- Get formatted hotkey display text
function HotkeyConfig.getDisplayText(action)
    local key = HotkeyConfig.getHotkey(action)
    local formattedKey = HotkeyConfig.formatKey(key)
    local description = HotkeyConfig.descriptions[action]
    
    if action == "target_enemy" then
        return formattedKey .. "+Click: " .. description:gsub(" %(Ctrl%+Click%)", "")
    else
        return formattedKey .. ": " .. description
    end
end

return HotkeyConfig
