-- Simple test for HotkeyConfig
local HotkeyConfig = require('src.hotkey_config')

print('Initializing HotkeyConfig...')
HotkeyConfig.init()

local action = 'map_window'
local orig = HotkeyConfig.getHotkey(action)
print(string.format('Original key for %s = %s', action, tostring(orig)))

local testKey = 'n'
print(string.format('Setting %s to %s', action, testKey))
local ok = HotkeyConfig.setHotkey(action, testKey)
if not ok then
    error('Failed to set hotkey for ' .. action)
end

local cur = HotkeyConfig.getHotkey(action)
if cur ~= testKey then
    error(string.format('getHotkey returned %s but expected %s', tostring(cur), tostring(testKey)))
end

local act = HotkeyConfig.getActionForKey(testKey)
if act ~= action then
    error(string.format('getActionForKey returned %s but expected %s', tostring(act), tostring(action)))
end

print('Hotkey set/get tests passed')

-- Restore original
HotkeyConfig.setHotkey(action, orig)
print('Restored original key:', orig)
