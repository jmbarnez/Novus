---@diagnostic disable: undefined-global
-- ============================================================================
-- Hotkey Configuration Panel
-- ============================================================================
-- Handles hotkey button creation, display, and key assignment for settings window

local Theme = require('src.ui.plasma_theme')
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
    local buttonHeight = Theme.spacing.sm * 3.33  -- Scaled button height
    local buttonSpacing = Theme.spacing.sm  -- Scaled spacing

    -- Compute start Y to align with hotkeys label (6 sections: VSync, FPS, Resolution, Master, Music, SFX)
    local sectionSpacing = Theme.spacing.sm * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.sm * 2  -- Offset controls below labels
    local hotkeyStartY = sectionSpacing * 6 + controlVerticalOffset
    
    -- Build buttons with section headers using HotkeyConfig.actionSections
    local yOffset = hotkeyStartY
    local lastSection = nil
    for i, hotkey in ipairs(hotkeys) do
        local section = HotkeyConfig.actionSections[hotkey.action]
        if not section then
            section = "Other"
        end

        if section ~= lastSection then
            local title = (HotkeyConfig.sectionTitles and HotkeyConfig.sectionTitles[section]) or section
            table.insert(self.buttons, {
                type = "section",
                title = title,
                x = position.x,
                y = position.y + yOffset - contentScrollY,
                width = self.width,
                height = buttonHeight * 0.8
            })
            yOffset = yOffset + buttonHeight * 0.8 + buttonSpacing
            lastSection = section
        end

        table.insert(self.buttons, {
            type = "button",
            action = hotkey.action,
            description = hotkey.description,
            key = hotkey.key,
            x = position.x,
            y = position.y + yOffset - contentScrollY,
            width = self.width,
            height = buttonHeight
        })
        yOffset = yOffset + buttonHeight + buttonSpacing
    end
end

-- Update button positions for scrolling
function HotkeyConfigPanel:updatePositions(position, contentScrollY)
    self.position = position
    self.contentScrollY = contentScrollY

    local buttonHeight = Theme.spacing.sm * 3.33  -- Scaled button height
    local buttonSpacing = Theme.spacing.sm  -- Scaled spacing
    local sectionSpacing = Theme.spacing.sm * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.sm * 2  -- Offset controls below labels
    
    -- Calculate start Y to align with hotkeys label (6 sections: VSync, FPS, Resolution, Master, Music, SFX)
    local hotkeyStartY = sectionSpacing * 6 + controlVerticalOffset

    -- Recompute positions respecting per-button heights (section headers may differ)
    local yOffset = hotkeyStartY
    for i, button in ipairs(self.buttons) do
        button.x = position.x
        button.y = position.y + yOffset - contentScrollY
        button.width = self.width
        -- advance yOffset by this button's height plus spacing
        local h = button.height or buttonHeight
        yOffset = yOffset + h + buttonSpacing
    end
end

-- Draw hotkey buttons
function HotkeyConfigPanel:draw(alpha)
    if not self.buttons then return end
    
    local mx, my = love.mouse.getPosition()
    
    for i, button in ipairs(self.buttons) do
        if button.type == "section" then
            -- Draw section header (green)
            local col = Theme.colors.success or Theme.colors.textSecondary
            love.graphics.setColor(col[1], col[2], col[3], (col[4] or 1) * alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.printf(button.title, button.x + 8, button.y + 4, button.width - 16, "left")
        else
            local hovered = mx >= button.x and mx <= button.x + button.width and 
                           my >= button.y and my <= button.y + button.height
            local selected = self.selectedHotkey == button.action
            
            -- Button background
            if selected or self.waitingForKey then
                love.graphics.setColor(Theme.colors.hover[1], Theme.colors.hover[2],
                                     Theme.colors.hover[3], alpha * 0.8)
            elseif hovered then
                love.graphics.setColor(Theme.colors.hover[1], Theme.colors.hover[2],
                                     Theme.colors.hover[3], alpha * 0.4)
            else
                love.graphics.setColor(Theme.colors.surfaceAlt[1], Theme.colors.surfaceAlt[2],
                                     Theme.colors.surfaceAlt[3], alpha * 0.6)
            end
            
            local cornerRadius = Theme.window.cornerRadius or 0
            love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, cornerRadius, cornerRadius)
            
            -- Button border
            love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2],
                                 Theme.colors.borderAlt[3], alpha)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", button.x, button.y, button.width, button.height, cornerRadius, cornerRadius)
            
            -- Button text
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2],
                                 Theme.colors.text[3], alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            
            local displayText = HotkeyConfig.getDisplayText(button.action)
            if self.waitingForKey and selected then
                displayText = "Press any key..."
            end
            
            love.graphics.printf(displayText, button.x + 8, button.y + 4, button.width - 16, "left")
        end
    end
end

-- Handle hotkey button clicks
function HotkeyConfigPanel:handleClick(mx, my)
    if not self.buttons then return false end
    
    for i, button in ipairs(self.buttons) do
        if button.type == "section" then
            -- Section headers are not clickable
            return false
        end
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
