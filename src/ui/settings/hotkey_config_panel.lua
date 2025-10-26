---@diagnostic disable: undefined-global
-- ============================================================================
-- Hotkey Configuration Panel
-- ============================================================================
-- Handles hotkey button creation, display, and key assignment for settings window

local Theme = require('src.ui.theme')
local HotkeyConfig = require('src.hotkey_config')

local HotkeyConfigPanel = {}

function HotkeyConfigPanel:new()
    local panel = {
        buttons = {},
        selectedHotkey = nil,
        waitingForKey = false,
        position = {x = 0, y = 0},
        width = 0,
        contentScrollY = 0
    }
    setmetatable(panel, self)
    self.__index = self
    return panel
end

-- Initialize hotkey buttons
function HotkeyConfigPanel:initialize(position, width, contentScrollY)
    self.position = position
    self.width = width
    self.contentScrollY = contentScrollY
    self.buttons = {}
    
    local hotkeys = HotkeyConfig.getAllHotkeys()
    local buttonHeight = Theme.spacing.padding * 3.33  -- Scaled button height
    local buttonSpacing = Theme.spacing.padding  -- Scaled spacing

    -- Compute start Y to align with hotkeys label (5 sections: FPS, Resolution, Master, Music, SFX)
    local sectionSpacing = Theme.spacing.padding * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.padding * 2  -- Offset controls below labels
    local hotkeyStartY = sectionSpacing * 5 + controlVerticalOffset
    
    for i, hotkey in ipairs(hotkeys) do
        table.insert(self.buttons, {
            action = hotkey.action,
            description = hotkey.description,
            key = hotkey.key,
            x = position.x,
            y = position.y + hotkeyStartY + (i - 1) * (buttonHeight + buttonSpacing) - contentScrollY,
            width = self.width,
            height = buttonHeight
        })
    end
end

-- Update button positions for scrolling
function HotkeyConfigPanel:updatePositions(position, contentScrollY)
    self.position = position
    self.contentScrollY = contentScrollY

    local buttonHeight = Theme.spacing.padding * 3.33  -- Scaled button height
    local buttonSpacing = Theme.spacing.padding  -- Scaled spacing
    local sectionSpacing = Theme.spacing.padding * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.padding * 2  -- Offset controls below labels
    
    -- Calculate start Y to align with hotkeys label (5 sections: FPS, Resolution, Master, Music, SFX)
    local hotkeyStartY = sectionSpacing * 5 + controlVerticalOffset

    for i, button in ipairs(self.buttons) do
        button.x = position.x
        button.y = position.y + hotkeyStartY + (i - 1) * (buttonHeight + buttonSpacing) - contentScrollY
        button.width = self.width
    end
end

-- Draw hotkey buttons
function HotkeyConfigPanel:draw(alpha)
    if not self.buttons then return end
    
    local mx, my = love.mouse.getPosition()
    
    for i, button in ipairs(self.buttons) do
        local hovered = mx >= button.x and mx <= button.x + button.width and 
                       my >= button.y and my <= button.y + button.height
        local selected = self.selectedHotkey == button.action
        
        -- Button background
        if selected or self.waitingForKey then
            love.graphics.setColor(Theme.colors.buttonHover[1], Theme.colors.buttonHover[2], 
                                 Theme.colors.buttonHover[3], alpha * 0.8)
        elseif hovered then
            love.graphics.setColor(Theme.colors.buttonHover[1], Theme.colors.buttonHover[2], 
                                 Theme.colors.buttonHover[3], alpha * 0.4)
        else
            love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], 
                                 Theme.colors.bgMedium[3], alpha * 0.6)
        end
        
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 4, 4)
        
        -- Button border
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], 
                             Theme.colors.borderMedium[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 4, 4)
        
        -- Button text
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], 
                             Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        
        local displayText = HotkeyConfig.getDisplayText(button.action)
        if self.waitingForKey and selected then
            displayText = "Press any key..."
        end
        
        love.graphics.printf(displayText, button.x + 8, button.y + 4, button.width - 16, "left")
    end
end

-- Handle hotkey button clicks
function HotkeyConfigPanel:handleClick(mx, my)
    if not self.buttons then return false end
    
    for i, button in ipairs(self.buttons) do
        if mx >= button.x and mx <= button.x + button.width and
           my >= button.y and my <= button.y + button.height then
            
            if self.waitingForKey then
                -- Cancel key assignment
                self.waitingForKey = false
                self.selectedHotkey = nil
            else
                -- Start waiting for key
                self.waitingForKey = true
                self.selectedHotkey = button.action
            end
            return true
        end
    end
    
    return false
end

-- Handle key input for hotkey assignment
function HotkeyConfigPanel:handleKeyPress(key)
    if self.waitingForKey and self.selectedHotkey then
        -- Check if key is already mapped to another action
        local existingAction = HotkeyConfig.getActionForKey(key)
        if existingAction and existingAction ~= self.selectedHotkey then
            -- Swap the keys
            local oldKey = HotkeyConfig.getHotkey(self.selectedHotkey)
            HotkeyConfig.setHotkey(existingAction, oldKey)
        end
        
        -- Set the new key
        HotkeyConfig.setHotkey(self.selectedHotkey, key)
        
        -- Update button display
        for i, button in ipairs(self.buttons) do
            if button.action == self.selectedHotkey then
                button.key = key
                break
            end
        end
        
        -- Stop waiting
        self.waitingForKey = false
        self.selectedHotkey = nil
        return true
    end
    
    return false
end

-- Get current hotkey settings for saving
function HotkeyConfigPanel:getSettings()
    local settings = {}
    local hotkeys = HotkeyConfig.getAllHotkeys()
    for i, hotkey in ipairs(hotkeys) do
        settings[hotkey.action] = HotkeyConfig.getHotkey(hotkey.action)
    end
    return settings
end

-- Restore hotkey settings
function HotkeyConfigPanel:restoreSettings(settings)
    if not settings then return end
    
    for action, key in pairs(settings) do
        HotkeyConfig.setHotkey(action, key)
    end
end

return HotkeyConfigPanel
