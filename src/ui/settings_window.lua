---@diagnostic disable: undefined-global
-- ============================================================================
-- Settings Window with Dropdown Menus
-- ============================================================================
-- Provides a UI for adjusting game settings using dropdown menus:
--   - FPS limit dropdown
--   - Window mode dropdown
--   - Resolution dropdown (when in windowed mode)
--   - Exit game button

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')
local Dropdown = require('src.ui.dropdown')

local SettingsWindow = WindowBase:new{
    width = 480,
    height = 280,
    isOpen = false,
    animAlphaSpeed = 2.0,
    
    -- Dropdown components
    fpsDropdown = nil,
    modeDropdown = nil,
    resDropdown = nil,
    _exitBtn = nil,
    _initialized = false
}

-- FPS Configuration
SettingsWindow.fpsOptions = {30, 60, 90, 120, 144, 240, nil}
SettingsWindow.fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"}

-- Window modes
SettingsWindow.modes = { 'Windowed', 'Borderless', 'Fullscreen' }

-- Resolutions
SettingsWindow.resolutions = {
    {w = 1280, h = 720, label = "1280x720"},
    {w = 1366, h = 768, label = "1366x768"},
    {w = 1600, h = 900, label = "1600x900"},
    {w = 1920, h = 1080, label = "1920x1080"},
    {w = 2560, h = 1440, label = "2560x1440"},
}

-- Get current FPS index
function SettingsWindow:currentFpsIndex()
    local curFps = TimeManager.getTargetFps()
    for i, v in ipairs(self.fpsOptions) do
        if v == curFps then return i end
    end
    return #self.fpsOptions
end

-- Get current window mode index
function SettingsWindow:currentModeIndex()
    local _, _, flags = love.window.getMode()
    if flags.fullscreen then return 3 end
    if flags.borderless and not flags.fullscreen then return 2 end
    return 1
end

-- Get current resolution index
function SettingsWindow:getCurrentResIndex()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    for i, res in ipairs(self.resolutions) do
        if res.w == w and res.h == h then return i end
    end
    return 4  -- Default to 1920x1080
end

-- Initialize dropdowns on first draw
function SettingsWindow:initialize()
    if self._initialized then return end
    
    local x, y = self.position.x + 30, self.position.y + 60
    local dropdownWidth = self.width - 60
    
    -- FPS Dropdown
    self.fpsDropdown = Dropdown:new(self.fpsLabels, self:currentFpsIndex(), x, y, dropdownWidth, function(idx, val)
        TimeManager.setTargetFps(self.fpsOptions[idx])
    end)
    
    -- Mode Dropdown
    self.modeDropdown = Dropdown:new(self.modes, self:currentModeIndex(), x, y + 50, dropdownWidth, function(idx, val)
        if idx == 1 then
            love.window.setMode(1920, 1080, {fullscreen = false, borderless = false})
        elseif idx == 2 then
            love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), {fullscreen = false, borderless = true})
        elseif idx == 3 then
            love.window.setMode(0, 0, {fullscreen = true})
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
        x, y + 100, 
        dropdownWidth, 
        function(idx, val)
            local res = self.resolutions[idx]
            love.window.setMode(res.w, res.h, {fullscreen = false, borderless = false})
        end
    )
    
    self._initialized = true
end

-- Toggle window open/close
function SettingsWindow:toggle()
    self:setOpen(not self.isOpen)
end

-- Get window open state
function SettingsWindow:getOpen()
    return self.isOpen
end

-- Main draw function
function SettingsWindow:draw()
    if not self.isOpen or not self.position then return end
    
    WindowBase.draw(self)
    
    local x, y = self.position.x, self.position.y
    local alpha = self.animAlpha
    
    self:initialize()
    
    -- Title
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Settings", x + 10, y + 6, self.width - 20, "left")
    
    -- Labels (draw BEFORE dropdowns so they don't overlap)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.textAccent)
    
    love.graphics.print("FPS Limit:", x + 30, y + 42)
    love.graphics.print("Window Mode:", x + 30, y + 92)
    love.graphics.print("Resolution:", x + 30, y + 142)
    
    -- Exit Button
    local btnW, btnH = 140, 34
    local btnX = x + (self.width - btnW) / 2
    local btnY = y + self.height - 50
    
    self._exitBtn = {x = btnX, y = btnY, w = btnW, h = btnH}
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local hovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    love.graphics.setColor(hovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.printf('Exit Game', btnX, btnY + 8, btnW, 'center')
    
    -- Close button
    self:drawCloseButton(x, y, alpha)
    
    -- Draw closed dropdown buttons first
    self.fpsDropdown:drawClosed(alpha)
    self.modeDropdown:drawClosed(alpha)
    self.resDropdown:drawClosed(alpha)
    
    -- Draw open dropdown menus LAST so they render on top of everything else
    if self.fpsDropdown.isOpen then
        self.fpsDropdown:drawOpen(alpha)
    end
    if self.modeDropdown.isOpen then
        self.modeDropdown:drawOpen(alpha)
    end
    if self.resDropdown.isOpen then
        self.resDropdown:drawOpen(alpha)
    end
end

-- Mouse input
function SettingsWindow:mousepressed(mx, my, button)
    if button ~= 1 then return end
    
    if not self.isOpen then return end
    
    self:initialize()
    
    -- Try dropdowns first
    if self.fpsDropdown and self.fpsDropdown:mousepressed(mx, my) then return end
    if self.modeDropdown and self.modeDropdown:mousepressed(mx, my) then return end
    if self.resDropdown and self.resDropdown:mousepressed(mx, my) then return end
    
    -- Exit button
    if self._exitBtn and mx >= self._exitBtn.x and mx <= self._exitBtn.x + self._exitBtn.w and
       my >= self._exitBtn.y and my <= self._exitBtn.y + self._exitBtn.h then
        love.event.quit()
        return true
    end
    
    WindowBase.mousepressed(self, mx, my, button)
end

function SettingsWindow:mousereleased(mx, my, button)
    WindowBase.mousereleased(self, mx, my, button)
end

function SettingsWindow:mousemoved(mx, my, dx, dy)
    WindowBase.mousemoved(self, mx, my, dx, dy)
end

return SettingsWindow
