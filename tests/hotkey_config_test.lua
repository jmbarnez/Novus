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

print('Testing formatKey with nil input...')
local ok, formatted = pcall(HotkeyConfig.formatKey, nil)
if not ok then
    error('formatKey should handle nil input without error')
end
if formatted ~= 'Unbound' then
    error(string.format('formatKey(nil) returned %s, expected %s', tostring(formatted), 'Unbound'))
end

print('Testing display text when key is unbound...')
-- Use the public API to set an unbound key rather than mutating internals
local okSet = HotkeyConfig.setHotkey(action, '')
if not okSet then error('Failed to set hotkey to empty for test') end
local displayText = HotkeyConfig.getDisplayText(action)
if not displayText:match('Unbound') then
    error(string.format('Display text for unbound key did not include "Unbound": %s', displayText))
end

local targetOrig = HotkeyConfig.getHotkey('target_enemy')
-- Set via public API
local okTargetSet = HotkeyConfig.setHotkey('target_enemy', '')
if not okTargetSet then error('Failed to set target_enemy to empty for test') end
local targetDisplay = HotkeyConfig.getDisplayText('target_enemy')
if targetDisplay:match('Unbound%+Click') then
    error(string.format('Display text for unbound target_enemy should not include +Click: %s', targetDisplay))
end
HotkeyConfig.setHotkey('target_enemy', targetOrig)

print('Testing display text for unknown action fallback...')
local okFallback, fallbackText = pcall(HotkeyConfig.getDisplayText, 'mystery_action')
if not okFallback then
    error('getDisplayText should not error for unknown actions')
end
if not fallbackText:match('Unbound: Mystery Action') then
    error(string.format('Fallback display text unexpected: %s', fallbackText))
end

-- Restore original
HotkeyConfig.setHotkey(action, orig)
print('Restored original key:', orig)
