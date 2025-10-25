---@diagnostic disable: undefined-global
-- ============================================================================
-- Display Settings Panel
-- ============================================================================
-- Handles display settings (FPS, resolution, window mode) for settings window

local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local TimeManager = require('src.time_manager')
local Dropdown = require('src.ui.dropdown')

local DisplaySettingsPanel = {}

function DisplaySettingsPanel:new()
    local panel = {
        fpsDropdown = nil,
        modeDropdown = nil,
        resDropdown = nil,
        position = {x = 0, y = 0},
        width = 0,
        onSettingsChange = nil,
        
        -- FPS Configuration
        fpsOptions = {30, 60, 90, 120, 144, 240, nil},
        fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"},
        
        -- Window modes
        modes = { 'Windowed', 'Borderless', 'Fullscreen' },
        
        -- Resolutions
        resolutions = {
            {w = 1280, h = 720, label = "1280x720"},
            {w = 1366, h = 768, label = "1366x768"},
            {w = 1600, h = 900, label = "1600x900"},
            {w = 1920, h = 1080, label = "1920x1080"},
            {w = 2560, h = 1440, label = "2560x1440"},
        }
    }
    setmetatable(panel, self)
    self.__index = self
    return panel
end

-- Initialize display dropdowns
function DisplaySettingsPanel:initialize(position, width, onSettingsChange)
    self.position = position
    self.width = width
    self.onSettingsChange = onSettingsChange
    
    local x, y = position.x, position.y
    
    -- FPS Dropdown
    self.fpsDropdown = Dropdown:new(self.fpsLabels, self:currentFpsIndex(), x, y, width, function(idx, val)
        TimeManager.setTargetFps(self.fpsOptions[idx])
        if self.onSettingsChange then
            self.onSettingsChange()
        end
    end)
    
    -- Mode Dropdown
    self.modeDropdown = Dropdown:new(self.modes, self:currentModeIndex(), x, y + 60, width, function(idx, val)
        self:setWindowMode(idx)
        if self.onSettingsChange then
            self.onSettingsChange()
        end
    end)
    
    -- Resolution Dropdown
    local resLabels = {}
    for i, res in ipairs(self.resolutions) do
        table.insert(resLabels, res.label)
    end
    
    self.resDropdown = Dropdown:new(
        resLabels,
        self:getCurrentResIndex(), 
        x, y + 120, 
        width, 
        function(idx, val)
            local res = self.resolutions[idx]
            love.window.setMode(res.w, res.h, {fullscreen = false, borderless = false})
            if self.onSettingsChange then
                self.onSettingsChange()
            end
        end
    )
end

-- Update dropdown positions for scrolling
function DisplaySettingsPanel:updatePositions(position, contentScrollY)
    self.position = position
    local x, y = position.x, position.y - contentScrollY
    
    if self.fpsDropdown then
        self.fpsDropdown.x = x
        self.fpsDropdown.y = y
    end
    
    if self.modeDropdown then
        self.modeDropdown.x = x
        self.modeDropdown.y = y + 60
    end
    
    if self.resDropdown then
        self.resDropdown.x = x
        self.resDropdown.y = y + 120
    end
end

-- Get current FPS index
function DisplaySettingsPanel:currentFpsIndex()
    local curFps = TimeManager.getTargetFps()
    for i, v in ipairs(self.fpsOptions) do
        if v == curFps then return i end
    end
    return #self.fpsOptions
end

-- Get current window mode index
function DisplaySettingsPanel:currentModeIndex()
    local _, _, flags = love.window.getMode()
    if flags.fullscreen then return 3 end
    if flags.borderless then return 2 end
    return 1
end

-- Get current resolution index
function DisplaySettingsPanel:getCurrentResIndex()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    for i, res in ipairs(self.resolutions) do
        if res.w == w and res.h == h then return i end
    end
    -- Default to current window resolution
    local currentW, currentH = Constants.getScreenWidth(), Constants.getScreenHeight()
    for i, res in ipairs(self.resolutions) do
        if res.w == currentW and res.h == currentH then return i end
    end
    return 4  -- Default to 1920x1080 if not found
end

-- Set window mode based on index
function DisplaySettingsPanel:setWindowMode(idx)
    if idx == 1 then
        -- Windowed: restore a sane default windowed resolution
        local currentW, currentH = Constants.getScreenWidth(), Constants.getScreenHeight()
        love.window.setMode(currentW, currentH, {fullscreen = false, borderless = false})
    elseif idx == 2 then
        -- Borderless: set to desktop resolution and borderless to avoid mode-switch flashes
        local ok, dw, dh = pcall(love.window.getDesktopDimensions)
        if ok and dw and dh and dw > 0 then
            love.window.setMode(dw, dh, {fullscreen = false, borderless = true})
        else
            -- Fallback to current size
            love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), {fullscreen = false, borderless = true})
        end
    elseif idx == 3 then
        -- Fullscreen: use desktop/fullscreen desktop type to avoid exclusive mode flicker
        love.window.setMode(0, 0, {fullscreen = true, fullscreentype = "desktop"})
    end
end

-- Draw display dropdowns
function DisplaySettingsPanel:draw(alpha)
    -- Draw closed dropdown buttons first
    if self.fpsDropdown then
        self.fpsDropdown:drawClosed(alpha)
    end
    if self.modeDropdown then
        self.modeDropdown:drawClosed(alpha)
    end
    if self.resDropdown then
        self.resDropdown:drawClosed(alpha)
    end
end

-- Draw open dropdown menus (should be called after scissor is disabled)
function DisplaySettingsPanel:drawOpen(alpha)
    if self.fpsDropdown and self.fpsDropdown.isOpen then
        self.fpsDropdown:drawOpen(alpha)
    end
    if self.modeDropdown and self.modeDropdown.isOpen then
        self.modeDropdown:drawOpen(alpha)
    end
    if self.resDropdown and self.resDropdown.isOpen then
        self.resDropdown:drawOpen(alpha)
    end
end

-- Handle mouse press on dropdowns
function DisplaySettingsPanel:mousepressed(mx, my)
    if self.fpsDropdown and self.fpsDropdown:mousepressed(mx, my) then 
        return true
    end
    if self.modeDropdown and self.modeDropdown:mousepressed(mx, my) then 
        return true
    end
    if self.resDropdown and self.resDropdown:mousepressed(mx, my) then 
        return true
    end
    return false
end

-- Get current display settings for saving
function DisplaySettingsPanel:getSettings()
    return {
        fps = TimeManager.getTargetFps(),
        windowMode = self:currentModeIndex(),
        resolution = {w = love.graphics.getWidth(), h = love.graphics.getHeight()}
    }
end

-- Restore display settings
function DisplaySettingsPanel:restoreSettings(settings)
    if not settings then return end
    
    if settings.fps then
        TimeManager.setTargetFps(settings.fps)
    end
    
    if settings.windowMode then
        self:setWindowMode(settings.windowMode)
    end
    
    if settings.resolution then
        love.window.setMode(settings.resolution.w, settings.resolution.h, {fullscreen = false, borderless = false})
    end
end

return DisplaySettingsPanel
