---@diagnostic disable: undefined-global
-- ============================================================================
-- Settings Window with Dropdown Menus
-- ============================================================================
-- Provides a UI for adjusting game settings using dropdown menus:
--   - FPS limit dropdown
--   - Window mode dropdown
--   - Resolution dropdown (when in windowed mode)
--   - Audio volume sliders
--   - Hotkey configuration
--   - Exit game button

local Constants = require('src.constants')
local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')
local HotkeyConfig = require('src.hotkey_config')

-- Import settings panels
local HotkeyConfigPanel = require('src.ui.settings.hotkey_config_panel')
local AudioSettingsPanel = require('src.ui.settings.audio_settings_panel')
local DisplaySettingsPanel = require('src.ui.settings.display_settings_panel')
local ScrollHandler = require('src.ui.settings.scroll_handler')
local BackgroundBlur = require('src.ui.settings.background_blur')

local SettingsWindow = WindowBase:new{
    width = 600,
    height = 500,
    isOpen = false,
    animAlphaSpeed = 2.0,
    
    -- Panel components
    hotkeyPanel = nil,
    audioPanel = nil,
    displayPanel = nil,
    scrollHandler = nil,
    backgroundBlur = nil,
    
    _exitBtn = nil,
    _initialized = false,
    
    -- Settings change tracking
    savedSettings = {}
}


-- Save current settings state as baseline
function SettingsWindow:saveSettingsSnapshot()
    self.savedSettings = {
        display = self.displayPanel and self.displayPanel:getSettings() or {},
        audio = self.audioPanel and self.audioPanel:getSettings() or {},
        hotkeys = self.hotkeyPanel and self.hotkeyPanel:getSettings() or {}
    }
end

-- Close the window
function SettingsWindow:closeWindow()
    self:setOpen(false)
end



-- Initialize panels on first draw
function SettingsWindow:initialize()
    if self._initialized then return end
    
    -- Save initial settings snapshot
    self:saveSettingsSnapshot()
    
    local x, y = self.position.x + 30, self.position.y + 60
    local dropdownWidth = self.width - 60
    
    -- Initialize background blur
    self.backgroundBlur = BackgroundBlur:new()
    
    -- Initialize scroll handler
    self.scrollHandler = ScrollHandler:new()
    local contentHeight = 540  -- Approximate total content height
    self.scrollHandler:initialize(self.position, self.width, self.height, contentHeight)
    
    -- Initialize display settings panel
    self.displayPanel = DisplaySettingsPanel:new()
    self.displayPanel:initialize({x = x, y = y}, dropdownWidth, function()
        self:saveSettingsSnapshot()
    end)
    
    -- Initialize audio settings panel
    self.audioPanel = AudioSettingsPanel:new()
    self.audioPanel:initialize({x = x, y = y}, dropdownWidth, function()
        self:saveSettingsSnapshot()
    end)
    
    -- Initialize hotkey configuration panel
    self.hotkeyPanel = HotkeyConfigPanel:new()
    self.hotkeyPanel:initialize({x = x, y = y}, dropdownWidth, self.scrollHandler:getScrollY())
    
    self._initialized = true
end

-- Update panel positions for scrolling
function SettingsWindow:updatePanelPositions()
    if not self._initialized or not self.position then return end
    
    local x, y = self.position.x + 30, self.position.y + 60
    local scrollY = self.scrollHandler:getScrollY()
    
    -- Update display panel positions
    if self.displayPanel then
        self.displayPanel:updatePositions({x = x, y = y}, scrollY)
    end
    
    -- Update audio panel positions
    if self.audioPanel then
        self.audioPanel:updatePositions({x = x, y = y}, scrollY)
    end
    
    -- Update hotkey panel positions
    if self.hotkeyPanel then
        self.hotkeyPanel:updatePositions({x = x, y = y}, scrollY)
    end
end

-- Toggle window open/close
function SettingsWindow:toggle()
    if self.isOpen then
        self:closeWindow()
    else
        self:setOpen(true)
    end
end

-- Override setOpen to capture a downscaled snapshot for blur
function SettingsWindow:setOpen(state)
    WindowBase.setOpen(self, state)

    -- When opening, capture background for blur effect
    if state and self.backgroundBlur then
        self.backgroundBlur:captureBackground()
    end
end

-- Get window open state
function SettingsWindow:getOpen()
    return self.isOpen
end

-- Main draw function
function SettingsWindow:draw()
    if not self.isOpen or not self.position then return end
    
    -- Draw blurred background
    if self.backgroundBlur then
        self.backgroundBlur:draw(self.animAlpha)
    else
        -- Fallback to semi-transparent glass
        love.graphics.setColor(0, 0, 0, 0.3 * self.animAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    WindowBase.draw(self)
    
    local x, y = self.position.x, self.position.y
    local alpha = self.animAlpha
    
    self:initialize()
    self:updatePanelPositions()
    
    -- Title (always visible at top)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Settings", x + 10, y + 6, self.width - 20, "left")
    
    -- Set up scissor/clip region for scrollable content
    local topBarH = Theme.window.topBarHeight
    local contentAreaX = x + 3
    local contentAreaY = y + topBarH + 3
    local contentAreaW = self.width - 6 - 20  -- Leave space for scroll bar
    local contentAreaH = self.height - topBarH - 3 - 3 - Theme.window.bottomBarHeight  -- Account for bottom bar area
    
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)
    
    -- Labels (draw BEFORE panels so they don't overlap)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.textAccent)
    
    local scrollY = self.scrollHandler:getScrollY()
    love.graphics.print("FPS Limit:", x + 30, y + 42 - scrollY)
    love.graphics.print("Window Mode:", x + 30, y + 102 - scrollY)
    love.graphics.print("Resolution:", x + 30, y + 162 - scrollY)
    love.graphics.print("Master Volume:", x + 30, y + 222 - scrollY)
    love.graphics.print("Music Volume:", x + 30, y + 282 - scrollY)
    love.graphics.print("SFX Volume:", x + 30, y + 342 - scrollY)
    love.graphics.print("Hotkeys:", x + 30, y + 402 - scrollY)
    
    -- Draw panels (inside scissor region)
    if self.displayPanel then
        self.displayPanel:draw(alpha)
    end
    if self.audioPanel then
        self.audioPanel:draw(alpha)
    end
    if self.hotkeyPanel then
        self.hotkeyPanel:draw(alpha)
    end
    
    -- Disable scissor to draw dropdown menus outside clipping area
    love.graphics.setScissor()
    
    -- Draw open dropdown menus LAST so they render on top of everything else (without clipping)
    if self.displayPanel then
        self.displayPanel:drawOpen(alpha)
    end
    
    -- Disable scissor
    love.graphics.setScissor()
    
    -- Exit to Main Menu Button (positioned in bottom bar)
    local btnW, btnH = 160, 34
    local startX = x + (self.width - btnW) / 2
    
    -- Position button in the bottom bar area
    local btnY = y + self.height - Theme.window.bottomBarHeight + (Theme.window.bottomBarHeight - btnH) / 2
    
    self._exitBtn = {x = startX, y = btnY, w = btnW, h = btnH}
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    -- Exit to Main Menu Button (red)
    local exitHovered = mx >= startX and mx <= startX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(exitHovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', startX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.printf('Exit to Main Menu', startX, btnY + 8, btnW, 'center')
    
    -- Close button
    self:drawCloseButton(x, y, alpha)
    
    -- Draw scroll bar (outside scissor, positioned on the side)
    if self.scrollHandler then
        self.scrollHandler:draw(alpha)
    end
end

-- Mouse input
function SettingsWindow:mousepressed(mx, my, button)
    if button ~= 1 then return end
    
    if not self.isOpen then return end
    
    self:initialize()
    self:updatePanelPositions()
    
    -- Convert screen coordinates to UI coordinates
    local uiMx, uiMy = mx, my
    
    -- Check Exit to Main Menu button FIRST (before any scrollable content)
    -- This prevents click-through to content behind it
    if self._exitBtn and uiMx >= self._exitBtn.x and uiMx <= self._exitBtn.x + self._exitBtn.w and
       uiMy >= self._exitBtn.y and uiMy <= self._exitBtn.y + self._exitBtn.h then
        self:closeWindow()
        if _G.Game and _G.Game.returnToMainMenu then
            _G.Game.returnToMainMenu()
        end
        return true
    end
    
    -- Check close button (from WindowBase)
    local closeBtn = {
        x = self.position.x + self.width - 35,
        y = self.position.y + 5,
        w = 30,
        h = 20
    }
    if uiMx >= closeBtn.x and uiMx <= closeBtn.x + closeBtn.w and
       uiMy >= closeBtn.y and uiMy <= closeBtn.y + closeBtn.h then
        self:closeWindow()
        return true
    end
    
    -- Check scroll bar BEFORE content (to prevent click-through)
    if self.scrollHandler and self.scrollHandler:handleScrollBarClick(uiMx, uiMy) then return true end
    
    -- Try display panel dropdowns (these can extend outside the content area when open)
    if self.displayPanel and self.displayPanel:mousepressed(uiMx, uiMy) then return true end
    
    -- Try audio panel sliders (in scrollable content)
    if self.audioPanel and self.audioPanel:mousepressed(uiMx, uiMy, button) then return true end
    
    -- Try hotkey panel buttons (in scrollable content)
    if self.hotkeyPanel and self.hotkeyPanel:handleClick(uiMx, uiMy) then return true end
    
    -- Check if clicking on the window itself (to capture and prevent click-through)
    if uiMx >= self.position.x and uiMx <= self.position.x + self.width and
       uiMy >= self.position.y and uiMy <= self.position.y + self.height then
        return true
    end
    
    WindowBase.mousepressed(self, mx, my, button)
end

-- Handle key input for hotkey assignment
function SettingsWindow:keypressed(key)
    if self.hotkeyPanel and self.hotkeyPanel:handleKeyPress(key) then
        -- Auto-save settings
        self:saveSettingsSnapshot()
        return true
    end
    
    return false
end

function SettingsWindow:mousereleased(mx, my, button)
    -- Handle scroll bar mouse release
    if self.scrollHandler and self.scrollHandler:mousereleased(mx, my, button) then return true end
    
    self:initialize()
    self:updatePanelPositions()
    
    -- Convert screen coordinates to UI coordinates
    local uiMx, uiMy = mx, my
    
    -- Handle audio panel mouse release
    if self.audioPanel and self.audioPanel:mousereleased(uiMx, uiMy, button) then return true end
    
    WindowBase.mousereleased(self, mx, my, button)
end

function SettingsWindow:mousemoved(mx, my, dx, dy)
    self:initialize()
    self:updatePanelPositions()
    
    -- Handle scroll bar dragging
    if self.scrollHandler and self.scrollHandler:mousemoved(mx, my, dx, dy) then return true end
    
    -- Convert screen coordinates to UI coordinates
    local uiMx, uiMy = mx, my
    
    -- Handle audio panel mouse move
    if self.audioPanel and self.audioPanel:mousemoved(uiMx, uiMy, dx, dy) then return true end
    
    WindowBase.mousemoved(self, mx, my, dx, dy)
end

-- Handle mouse wheel scrolling
function SettingsWindow:wheelmoved(x, y)
    if not self.isOpen then return false end
    
    -- Check if mouse is over the settings window
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    if mx >= self.position.x and mx <= self.position.x + self.width and
       my >= self.position.y and my <= self.position.y + self.height then
        if self.scrollHandler then
            self.scrollHandler:updateScroll(-y)  -- Invert scroll direction
            self:updatePanelPositions()
        end
        return true
    end
    
    return false
end

return SettingsWindow
