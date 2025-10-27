---@diagnostic disable: undefined-global
-- ============================================================================
-- Display Settings Panel
-- ============================================================================
-- Handles display settings (FPS, resolution, window mode) for settings window

local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local TimeManager = require('src.time_manager')
local Dropdown = require('src.ui.dropdown')
local DisplayManager = require('src.display_manager')
local RenderCanvas = require('src.systems.render.canvas')

local DisplaySettingsPanel = {}

function DisplaySettingsPanel:new()
    local panel = {
        vsyncDropdown = nil,
        fpsDropdown = nil,
        modeDropdown = nil,
        resDropdown = nil,
        position = {x = 0, y = 0},
        width = 0,
        onSettingsChange = nil,
        
        -- FPS Configuration
        fpsOptions = {30, 60, 90, 120, 144, 240, nil},
        fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"},
        vsyncOptions = {true, false},
        vsyncLabels = {"On", "Off"},
        
    -- Window modes (restricted to Windowed only)
    modes = { 'Windowed' },
        
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
    
    -- VSync Dropdown
    self.vsyncDropdown = Dropdown:new(
        self.vsyncLabels,
        DisplayManager.isVsyncEnabled() and 1 or 2,
        x, y,
        width,
        function(idx)
            DisplayManager.setVsyncEnabled(self.vsyncOptions[idx])
            if self.onSettingsChange then
                self.onSettingsChange()
            end
        end
    )

    -- FPS Dropdown
    self.fpsDropdown = Dropdown:new(self.fpsLabels, self:currentFpsIndex(), x, y, width, function(idx, val)
        TimeManager.setTargetFps(self.fpsOptions[idx])
        if self.onSettingsChange then
            self.onSettingsChange()
        end
    end)
    
    -- Mode is fixed to Windowed in this build; no dropdown rendered.
    
    -- Resolution Dropdown
    local resLabels = {}
    for i, res in ipairs(self.resolutions) do
        table.insert(resLabels, res.label)
    end
    
    self.resDropdown = Dropdown:new(
        resLabels,
        self:getCurrentResIndex(), 
        x, y,  -- Will be positioned by updatePositions
        width, 
        function(idx, val)
            local res = self.resolutions[idx]
            if res then
                -- Use DisplayManager to properly set render resolution
                RenderCanvas.setRenderResolution(res.w, res.h)
                
                -- Update window mode if in windowed mode
                if DisplayManager.getWindowMode() == 'windowed' then
                    DisplayManager.applyWindowMode('windowed', { width = res.w, height = res.h })
                end
            end
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
    local sectionSpacing = Theme.spacing.padding * 12  -- Match settings window spacing
    local controlVerticalOffset = Theme.spacing.padding * 2  -- Offset controls below labels

    if self.vsyncDropdown then
        self.vsyncDropdown.x = x
        self.vsyncDropdown.y = y + controlVerticalOffset
    end

    if self.fpsDropdown then
        self.fpsDropdown.x = x
        self.fpsDropdown.y = y + sectionSpacing + controlVerticalOffset
    end

    if self.resDropdown then
        self.resDropdown.x = x
        self.resDropdown.y = y + sectionSpacing * 2 + controlVerticalOffset  -- Align with resolution label
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
    local renderW, renderH = DisplayManager.getRenderDimensions()
    for i, res in ipairs(self.resolutions) do
        if res.w == renderW and res.h == renderH then return i end
    end
    return 4  -- Default to 1920x1080 if not found
end

-- Set window mode based on index
function DisplaySettingsPanel:setWindowMode(idx)
    if idx == 1 then
        -- Windowed: use current render resolution as window size
        local renderRes = DisplayManager.getRenderResolution()
        DisplayManager.applyWindowMode('windowed', { width = renderRes.w, height = renderRes.h })
    elseif idx == 2 then
        -- Borderless: match desktop resolution
        DisplayManager.applyWindowMode('borderless')
    elseif idx == 3 then
        -- Fullscreen desktop (no exclusive mode flicker)
        DisplayManager.applyWindowMode('fullscreen')
    end
end

-- Draw display dropdowns
function DisplaySettingsPanel:draw(alpha)
    if self.vsyncDropdown then
        self.vsyncDropdown:drawClosed(alpha)
    end
    -- Draw closed dropdown buttons first
    if self.fpsDropdown then
        self.fpsDropdown:drawClosed(alpha)
    end
    if self.resDropdown then
        self.resDropdown:drawClosed(alpha)
    end
end

-- Draw open dropdown menus (should be called after scissor is disabled)
function DisplaySettingsPanel:drawOpen(alpha)
    if self.vsyncDropdown and self.vsyncDropdown.isOpen then
        self.vsyncDropdown:drawOpen(alpha)
    end
    if self.fpsDropdown and self.fpsDropdown.isOpen then
        self.fpsDropdown:drawOpen(alpha)
    end
    if self.resDropdown and self.resDropdown.isOpen then
        self.resDropdown:drawOpen(alpha)
    end
end

-- Handle mouse press on dropdowns
function DisplaySettingsPanel:mousepressed(mx, my)
    if self.vsyncDropdown and self.vsyncDropdown:mousepressed(mx, my) then 
        return true
    end
    if self.fpsDropdown and self.fpsDropdown:mousepressed(mx, my) then 
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
        resolution = DisplayManager.getRenderResolution(),
        vsync = DisplayManager.isVsyncEnabled()
    }
end

-- Restore display settings
function DisplaySettingsPanel:restoreSettings(settings)
    if not settings then return end

    if settings.vsync ~= nil then
        DisplayManager.setVsyncEnabled(settings.vsync)
        if self.vsyncDropdown then
            self.vsyncDropdown:setSelected(settings.vsync and 1 or 2)
        end
    end
    
    if settings.fps then
        TimeManager.setTargetFps(settings.fps)
    end
    
    if settings.windowMode then
        self:setWindowMode(settings.windowMode)
    end
    
    if settings.resolution then
        RenderCanvas.setRenderResolution(settings.resolution.w, settings.resolution.h)
    end
end

return DisplaySettingsPanel
