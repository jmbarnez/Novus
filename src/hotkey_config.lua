---@diagnostic disable: undefined-global
-- Hotkey Configuration System
-- Manages customizable hotkeys for the game

local HotkeyConfig = {}

local function formatActionLabel(action)
    if type(action) ~= "string" or action == "" then
        return "Unknown Action"
    end

    local words = {}
    for word in action:gmatch("[^_]+") do
        word = word:lower()
        word = word:gsub("^%l", string.upper)
        table.insert(words, word)
    end

    if #words == 0 then
        return "Unknown Action"
    end

    return table.concat(words, " ")
end

-- Default hotkey mappings
HotkeyConfig.defaults = {
    move_up = "w",
    move_down = "s", 
    move_left = "a",
    move_right = "d",
    target_enemy = "lctrl", -- Ctrl+Click
    cargo_window = "tab",
    -- skills_window and ship_window removed (no longer used)
    toggle_hud = "f5",
    map_window = "m",
    settings_window = "escape",
    hotbar_slot_1 = "q",
    hotbar_slot_2 = "e",
    hotbar_slot_3 = "r",
    hotbar_slot_4 = "v",
    hotbar_slot_5 = "lshift",
    hotbar_slot_6 = "1",
    hotbar_slot_7 = "2",
    hotbar_slot_8 = "3",
    hotbar_slot_9 = "4",
    hotbar_slot_10 = "5"
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
    -- skills_window and ship_window removed (no longer used)
    toggle_hud = "Toggle HUD",
    map_window = "Map Window",
    settings_window = "Settings Window",
    hotbar_slot_1 = "Hotbar Slot 1",
    hotbar_slot_2 = "Hotbar Slot 2",
    hotbar_slot_3 = "Hotbar Slot 3",
    hotbar_slot_4 = "Hotbar Slot 4",
    hotbar_slot_5 = "Hotbar Slot 5",
    hotbar_slot_6 = "Hotbar Slot 6",
    hotbar_slot_7 = "Hotbar Slot 7",
    hotbar_slot_8 = "Hotbar Slot 8",
    hotbar_slot_9 = "Hotbar Slot 9",
    hotbar_slot_10 = "Hotbar Slot 10"
}

-- Initialize hotkey configuration
function HotkeyConfig.init()
    -- Start from a clean table so removed/defaulted hotkeys don't linger
    HotkeyConfig.current = {}
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
    HotkeyConfig.init()
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
    if key == nil or key == "" then
        return "Unbound"
    end

    if type(key) ~= "string" then
        return tostring(key)
    end

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
    local description = HotkeyConfig.descriptions[action] or formatActionLabel(action)

    if action == "target_enemy" then
        local trimmedDescription = description:gsub(" %(Ctrl%+Click%)", "")
        if key == nil or key == "" then
            return formattedKey .. ": " .. trimmedDescription
        end
        return formattedKey .. "+Click: " .. trimmedDescription
    else
        return formattedKey .. ": " .. description
    end
end

return HotkeyConfig
