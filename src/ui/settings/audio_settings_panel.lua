---@diagnostic disable: undefined-global
-- ============================================================================
-- Audio Settings Panel
-- ============================================================================
-- Handles audio volume controls (master, music, SFX) for settings window

local Theme = require('src.ui.plasma_theme')
local Slider = require('src.ui.slider')

local AudioSettingsPanel = {}

function AudioSettingsPanel:new()
    local panel = {
        masterVolumeSlider = nil,
        musicVolumeSlider = nil,
        sfxVolumeSlider = nil,
        position = {x = 0, y = 0},
        width = 0,
        volumeMin = 0,
        volumeMax = 100,
        onSettingsChange = nil
    }
    setmetatable(panel, self)
    self.__index = self
    return panel
end

-- Initialize audio sliders
function AudioSettingsPanel:initialize(position, width, onSettingsChange)
    self.position = position
    self.width = width
    self.onSettingsChange = onSettingsChange
    
    local x, y = position.x, position.y

    -- Master Volume Slider
    self.masterVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("master"),
        x, y,  -- Will be positioned by updatePositions
        width - 50,  -- Leave space for value text
        Theme.spacing.sm * 3.33,  -- Scaled height
        function(value)
            self:setVolume("master", value)
            if self.onSettingsChange then
                self.onSettingsChange()
            end
        end
    )
    
    -- Music Volume Slider
    self.musicVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("music"),
        x, y,  -- Will be positioned by updatePositions
        width - 50,
        Theme.spacing.sm * 3.33,  -- Scaled height
        function(value)
            self:setVolume("music", value)
            if self.onSettingsChange then
                self.onSettingsChange()
            end
        end
    )
    
    -- SFX Volume Slider
    self.sfxVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("sfx"),
        x, y,  -- Will be positioned by updatePositions
        width - 50,
        Theme.spacing.sm * 3.33,  -- Scaled height
        function(value)
            self:setVolume("sfx", value)
            if self.onSettingsChange then
                self.onSettingsChange()
            end
        end
    )
end

-- Update slider positions for scrolling
function AudioSettingsPanel:updatePositions(position, contentScrollY)
    self.position = position
    local x, y = position.x, position.y - contentScrollY
    local sectionSpacing = Theme.spacing.sm * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.sm * 2  -- Offset controls below labels

    if self.masterVolumeSlider then
        self.masterVolumeSlider.x = x
        self.masterVolumeSlider.y = y + sectionSpacing * 3 + controlVerticalOffset  -- Align with Master Volume label
    end

    if self.musicVolumeSlider then
        self.musicVolumeSlider.x = x
        self.musicVolumeSlider.y = y + sectionSpacing * 4 + controlVerticalOffset  -- Align with Music Volume label
    end

    if self.sfxVolumeSlider then
        self.sfxVolumeSlider.x = x
        self.sfxVolumeSlider.y = y + sectionSpacing * 5 + controlVerticalOffset  -- Align with SFX Volume label
    end
end

-- Get current volume value for a given volume type
function AudioSettingsPanel:getCurrentVolume(volumeType)
    local SoundSystem = require('src.systems.sound')
    return SoundSystem.getVolume and SoundSystem.getVolume(volumeType) or 100
end

-- Set volume for a given type
function AudioSettingsPanel:setVolume(volumeType, value)
    local SoundSystem = require('src.systems.sound')
    if SoundSystem.setVolume then
        SoundSystem.setVolume(volumeType, value)
    end
end

-- Draw audio sliders
function AudioSettingsPanel:draw(alpha)
    if self.masterVolumeSlider then
        self.masterVolumeSlider:draw(alpha)
    end
    if self.musicVolumeSlider then
        self.musicVolumeSlider:draw(alpha)
    end
    if self.sfxVolumeSlider then
        self.sfxVolumeSlider:draw(alpha)
    end
end

-- Handle mouse press on sliders
function AudioSettingsPanel:mousepressed(mx, my, button)
    if self.masterVolumeSlider and self.masterVolumeSlider:mousepressed(mx, my, button) then 
        return true
    end
    if self.musicVolumeSlider and self.musicVolumeSlider:mousepressed(mx, my, button) then 
        return true
    end
    if self.sfxVolumeSlider and self.sfxVolumeSlider:mousepressed(mx, my, button) then 
        return true
    end
    return false
end

-- Handle mouse release on sliders
function AudioSettingsPanel:mousereleased(mx, my, button)
    if self.masterVolumeSlider and self.masterVolumeSlider:mousereleased(mx, my, button) then 
        return true
    end
    if self.musicVolumeSlider and self.musicVolumeSlider:mousereleased(mx, my, button) then 
        return true
    end
    if self.sfxVolumeSlider and self.sfxVolumeSlider:mousereleased(mx, my, button) then 
        return true
    end
    return false
end

-- Handle mouse move on sliders
function AudioSettingsPanel:mousemoved(mx, my, dx, dy)
    if self.masterVolumeSlider and self.masterVolumeSlider:mousemoved(mx, my, dx, dy) then 
        return true
    end
    if self.musicVolumeSlider and self.musicVolumeSlider:mousemoved(mx, my, dx, dy) then 
        return true
    end
    if self.sfxVolumeSlider and self.sfxVolumeSlider:mousemoved(mx, my, dx, dy) then 
        return true
    end
    return false
end

-- Get current audio settings for saving
function AudioSettingsPanel:getSettings()
    return {
        masterVolume = self:getCurrentVolume("master"),
        musicVolume = self:getCurrentVolume("music"),
        sfxVolume = self:getCurrentVolume("sfx")
    }
end

-- Restore audio settings
function AudioSettingsPanel:restoreSettings(settings)
    if not settings then return end
    
    if settings.masterVolume then
        self:setVolume("master", settings.masterVolume)
        if self.masterVolumeSlider then
            self.masterVolumeSlider:setValue(settings.masterVolume)
        end
    end
    
    if settings.musicVolume then
        self:setVolume("music", settings.musicVolume)
        if self.musicVolumeSlider then
            self.musicVolumeSlider:setValue(settings.musicVolume)
        end
    end
    
    if settings.sfxVolume then
        self:setVolume("sfx", settings.sfxVolume)
        if self.sfxVolumeSlider then
            self.sfxVolumeSlider:setValue(settings.sfxVolume)
        end
    end
end

return AudioSettingsPanel
