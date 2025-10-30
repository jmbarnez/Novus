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
    loadout_window = "g",
    skills_window = "p",
    -- skills_window and ship_window removed (no longer used)
    toggle_hud = "f5",
    map_window = "m",
    settings_window = "escape",
    hotbar_slot_1 = "mouse1",
    hotbar_slot_2 = "mouse2",
    hotbar_slot_3 = "q",
    hotbar_slot_4 = "e",
    hotbar_slot_5 = "r",
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
    loadout_window = "Loadout Window",
    skills_window = "Skills Window",
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

-- Optional: logical sections for UI grouping and ordering
HotkeyConfig.sectionOrder = {
    "Movement",
    "Targeting",
    "Windows",
    "Hotbar"
}

-- Map actions to a section name (actions not listed will appear in "Other")
HotkeyConfig.actionSections = {
    move_up = "Movement",
    move_down = "Movement",
    move_left = "Movement",
    move_right = "Movement",
    target_enemy = "Targeting",
    cargo_window = "Windows",
    map_window = "Windows",
    settings_window = "Windows",
    toggle_hud = "Windows",
    hotbar_slot_1 = "Hotbar",
    hotbar_slot_2 = "Hotbar",
    hotbar_slot_3 = "Hotbar",
    hotbar_slot_4 = "Hotbar",
    hotbar_slot_5 = "Hotbar",
    hotbar_slot_6 = "Hotbar",
    hotbar_slot_7 = "Hotbar",
    hotbar_slot_8 = "Hotbar",
    hotbar_slot_9 = "Hotbar",
    hotbar_slot_10 = "Hotbar"
}

-- Human-friendly section titles (can be used by UI)
HotkeyConfig.sectionTitles = {
    Movement = "Movement",
    Targeting = "Targeting",
    Windows = "Windows",
    Hotbar = "Hotbar",
    Other = "Other"
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
    local sections = {}
    local other = {}

    -- Collect actions into their sections
    for action, description in pairs(HotkeyConfig.descriptions) do
        local entry = {
            action = action,
            description = description,
            key = HotkeyConfig.getHotkey(action)
        }
        local section = HotkeyConfig.actionSections[action]
        if section then
            sections[section] = sections[section] or {}
            table.insert(sections[section], entry)
        else
            table.insert(other, entry)
        end
    end

    -- Helper to sort entries by description
    local function sortByDescription(a, b)
        return (a.description or "") < (b.description or "")
    end

    local result = {}

    -- Append sections in the configured order, sorted within each section
    for _, sectionName in ipairs(HotkeyConfig.sectionOrder) do
        local list = sections[sectionName]
        if list then
            table.sort(list, sortByDescription)
            for _, entry in ipairs(list) do
                table.insert(result, entry)
            end
        end
    end

    -- Append any remaining sections not present in sectionOrder (sorted by section name)
    local remainingSectionNames = {}
    for name, _ in pairs(sections) do
        local found = false
        for _, orderedName in ipairs(HotkeyConfig.sectionOrder) do
            if orderedName == name then found = true break end
        end
        if not found then table.insert(remainingSectionNames, name) end
    end
    table.sort(remainingSectionNames)
    for _, name in ipairs(remainingSectionNames) do
        local list = sections[name]
        table.sort(list, sortByDescription)
        for _, entry in ipairs(list) do
            table.insert(result, entry)
        end
    end

    -- Finally append unsectioned actions sorted by description
    table.sort(other, sortByDescription)
    for _, entry in ipairs(other) do
        table.insert(result, entry)
    end

    return result
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
        ["right"] = "→",
        ["mouse1"] = "LMB",
        ["mouse2"] = "RMB",
        ["mouse3"] = "MMB"
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
