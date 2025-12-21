local Settings = {}

local FILENAME = "settings.lua"

-- Default configuration
local DEFAULTS = {
    maxFps = 60,
    vsync = true,
    controls = {
        thrust = { "key:w", "key:up" },
        strafe_left = { "key:a", "key:left" },
        strafe_right = { "key:d", "key:right" },
        brake = { "key:space" },
        fire = { "mouse:1" },
        aim = { "mouse:2" },
        target_lock = { "key:lctrl", "key:rctrl" },
        interact = { "key:e" },
    }
}

-- Simple table serialization
local function serialize(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" then
            tmp = tmp .. "[" .. name .. "] = "
        else
            tmp = tmp .. "[\"" .. tostring(name) .. "\"] = "
        end
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. serialize(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

function Settings.load()
    if love.filesystem.getInfo(FILENAME) then
        local ok, chunk, err = pcall(love.filesystem.load, FILENAME)
        if not ok or not chunk then
            print("Error loading settings.lua (syntax error?): " .. tostring(err or chunk))
            print("Deleting corrupted settings file.")
            love.filesystem.remove(FILENAME)
            chunk = nil
        end

        if chunk then
            -- Wrap execution in pcall to catch syntax errors in the file
            local ok, data = pcall(chunk)
            if ok and data then
                Settings.data = data
                -- Merge defaults
                for k, v in pairs(DEFAULTS) do
                    if Settings.data[k] == nil then
                        Settings.data[k] = v
                    end
                end
                -- Deep merge controls
                if Settings.data.controls then
                    for k, v in pairs(DEFAULTS.controls) do
                        if Settings.data.controls[k] == nil then
                            Settings.data.controls[k] = v
                        end
                    end
                else
                    Settings.data.controls = DEFAULTS.controls
                end
                return
            else
                print("Error loading settings.lua: " .. tostring(data))
                print("Deleting corrupted settings file.")
                love.filesystem.remove(FILENAME)
            end
        end
    end

    -- Load defaults
    Settings.data = {}
    for k, v in pairs(DEFAULTS) do
        -- Deep copy controls
        if k == "controls" then
            Settings.data.controls = {}
            for action, keys in pairs(v) do
                Settings.data.controls[action] = {}
                for i, key in ipairs(keys) do
                    Settings.data.controls[action][i] = key
                end
            end
        else
            Settings.data[k] = v
        end
    end
end

function Settings.save()
    if not Settings.data then return end
    local content = "return " .. serialize(Settings.data)
    love.filesystem.write(FILENAME, content)
end

function Settings.get(key)
    if not Settings.data then Settings.load() end
    return Settings.data[key]
end

function Settings.set(key, value)
    if not Settings.data then Settings.load() end
    Settings.data[key] = value
    Settings.save()
end

function Settings.getControl(action)
    if not Settings.data then Settings.load() end
    return Settings.data.controls and Settings.data.controls[action]
end

function Settings.setControl(action, keys)
    if not Settings.data then Settings.load() end
    if not Settings.data.controls then Settings.data.controls = {} end
    Settings.data.controls[action] = keys
    Settings.save()
end

Settings.load()

return Settings
