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
local DisplayManager = require('src.display_manager')
local RenderCanvas = require('src.systems.render.canvas')

-- Import settings panels
local HotkeyConfigPanel = require('src.ui.settings.hotkey_config_panel')
local AudioSettingsPanel = require('src.ui.settings.audio_settings_panel')
local DisplaySettingsPanel = require('src.ui.settings.display_settings_panel')
local ScrollHandler = require('src.ui.settings.scroll_handler')

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
    
    _exitBtn = nil,
    _initialized = false,
    
    -- Settings change tracking
    savedSettings = {}
}

-- Canvas used to render a downscaled copy of the screen for a blur-like background
SettingsWindow._blurCanvas = nil
SettingsWindow._screenW = nil
SettingsWindow._screenH = nil

-- FPS Configuration
SettingsWindow.fpsOptions = {30, 60, 90, 120, 144, 240, nil}
SettingsWindow.fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"}

-- Window modes
SettingsWindow.modes = { 'Windowed', 'Borderless', 'Fullscreen' }

-- Resolutions (render resolution options)
SettingsWindow.resolutions = DisplayManager.renderResolutions

-- Audio volume range (0-100%)
SettingsWindow.volumeMin = 0
SettingsWindow.volumeMax = 100

-- Get current FPS index
function SettingsWindow:currentFpsIndex()
    local curFps = TimeManager.getTargetFps()
    for i, v in ipairs(self.fpsOptions) do
        if v == curFps then return i end
    end
    return #self.fpsOptions
end

-- Save current settings state as baseline
function SettingsWindow:saveSettingsSnapshot()
    self.savedSettings = {
        fps = TimeManager.getTargetFps(),
        windowMode = self:currentModeIndex(),
        resolution = DisplayManager.getRenderResolution(),
        hotkeys = {},
        audio = {
            masterVolume = SoundSystem.getVolume and SoundSystem.getVolume("master") or 100,
            musicVolume = SoundSystem.getVolume and SoundSystem.getVolume("music") or 100,
            sfxVolume = SoundSystem.getVolume and SoundSystem.getVolume("sfx") or 100
        }
    }
end

-- Close the window
function SettingsWindow:closeWindow()
    self:setOpen(false)
end

-- Get current window mode index
function SettingsWindow:currentModeIndex()
    local mode = DisplayManager.getWindowMode()
    if mode == 'fullscreen' then return 3 end
    if mode == 'borderless' then return 2 end
    return 1
end

-- Get current resolution index
function SettingsWindow:getCurrentResIndex()
    local index = DisplayManager.getRenderResolutionIndex()
    if index then return index end
    return 4  -- Default to 1920x1080 if not found
end

-- Get current volume value for a given volume type
function SettingsWindow:getCurrentVolume(volumeType)
    local SoundSystem = require('src.systems.sound')
    return SoundSystem.getVolume and SoundSystem.getVolume(volumeType) or 100
end

-- Draw hotkey configuration buttons
function SettingsWindow:drawHotkeyButtons(alpha)
    if not self.hotkeyButtons then return end
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    for i, button in ipairs(self.hotkeyButtons) do
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

-- Update scroll position
function SettingsWindow:updateScroll(deltaY)
    -- Always allow scroll updates, even if maxScrollY is 0 initially
    local scrollSpeed = 30
    self.contentScrollY = self.contentScrollY + deltaY * scrollSpeed
    
    -- Clamp scroll position if maxScrollY is available
    if self.maxScrollY > 0 then
        self.contentScrollY = math.max(0, math.min(self.maxScrollY, self.contentScrollY))
        
        -- Update scroll bar thumb position
        self.scrollBar.thumbY = self.scrollBar.y + (self.contentScrollY / self.maxScrollY) * (self.scrollBar.height - self.scrollBar.thumbHeight)
    else
        -- If no maxScrollY yet, just ensure we don't scroll below 0
        self.contentScrollY = math.max(0, self.contentScrollY)
    end
    
    -- Update all content positions
    self:updateDropdownPositions()
end

-- Draw scroll bar
function SettingsWindow:drawScrollBar(alpha)
    local sb = self.scrollBar
    local topBarH = Theme.window.topBarHeight
    
    -- Position scroll bar within content area only
    local contentAreaY = self.position.y + topBarH + 3
    local contentAreaH = self.height - topBarH - 3 - 3 - Theme.window.bottomBarHeight
    
    -- Update scroll bar position to be within content area
    sb.x = self.position.x + self.width - 20
    sb.y = contentAreaY
    sb.height = contentAreaH
    
    -- Always draw scroll bar background
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], 
                          Theme.colors.bgDark[3], alpha * 0.8)
    love.graphics.rectangle("fill", sb.x, sb.y, sb.width, sb.height, 2, 2)
    
    -- Scroll bar border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], 
                          Theme.colors.borderMedium[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sb.x, sb.y, sb.width, sb.height, 2, 2)
    
    -- Only draw thumb if there's scrollable content
    if self.maxScrollY > 0 then
        -- Scroll bar thumb
        local mx, my = Scaling.toUI(love.mouse.getPosition())
        local thumbHovered = mx >= sb.x and mx <= sb.x + sb.width and 
                            my >= sb.thumbY and my <= sb.thumbY + sb.thumbHeight
        
        if thumbHovered then
            love.graphics.setColor(Theme.colors.buttonHover[1], Theme.colors.buttonHover[2], 
                                 Theme.colors.buttonHover[3], alpha)
        else
            love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], 
                                 Theme.colors.borderLight[3], alpha)
        end
        love.graphics.rectangle("fill", sb.x + 1, sb.thumbY, sb.width - 2, sb.thumbHeight, 2, 2)
    end
end


-- Initialize panels on first draw
function SettingsWindow:initialize()
    if self._initialized then return end
    
    -- Save initial settings snapshot
    self:saveSettingsSnapshot()
    
    local x, y = self.position.x + 30, self.position.y + 60
    local dropdownWidth = self.width - 60
    
    -- FPS Dropdown
    self.fpsDropdown = Dropdown:new(self.fpsLabels, self:currentFpsIndex(), x, y, dropdownWidth, function(idx, val)
        TimeManager.setTargetFps(self.fpsOptions[idx])
        self:saveSettingsSnapshot()
    end)
    
    -- Mode Dropdown
    self.modeDropdown = Dropdown:new(self.modes, self:currentModeIndex(), x, y + 60, dropdownWidth, function(idx, val)
        local renderRes = DisplayManager.getRenderResolution()
        if idx == 1 then
            -- Windowed: use current render resolution as window size
            DisplayManager.applyWindowMode('windowed', { width = renderRes.w, height = renderRes.h })
        elseif idx == 2 then
            -- Borderless: match desktop resolution
            DisplayManager.applyWindowMode('borderless')
        elseif idx == 3 then
            -- Fullscreen desktop (no exclusive mode flicker)
            DisplayManager.applyWindowMode('fullscreen')
        end
        self:saveSettingsSnapshot()
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
        dropdownWidth, 
        function(idx, val)
            local res = self.resolutions[idx]
            if not res then return end

            RenderCanvas.setRenderResolution(res.w, res.h)

            if DisplayManager.getWindowMode() == 'windowed' then
                DisplayManager.applyWindowMode('windowed', { width = res.w, height = res.h })
            end

            self:saveSettingsSnapshot()
        end
    )
    
    -- Audio Volume Sliders
    self.masterVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("master"),
        x, y + 180,
        dropdownWidth - 50,  -- Leave space for value text
        20,
        function(value)
            local SoundSystem = require('src.systems.sound')
            if SoundSystem.setVolume then
                SoundSystem.setVolume("master", value)
            end
            self:saveSettingsSnapshot()
        end
    )
    
    self.musicVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("music"),
        x, y + 240,
        dropdownWidth - 50,
        20,
        function(value)
            local SoundSystem = require('src.systems.sound')
            if SoundSystem.setVolume then
                SoundSystem.setVolume("music", value)
            end
            self:saveSettingsSnapshot()
        end
    )
    
    self.sfxVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("sfx"),
        x, y + 300,
        dropdownWidth - 50,
        20,
        function(value)
            local SoundSystem = require('src.systems.sound')
            if SoundSystem.setVolume then
                SoundSystem.setVolume("sfx", value)
            end
            self:saveSettingsSnapshot()
        end
    )
    
    -- Initialize hotkey buttons
    self:initializeHotkeyButtons()
    
    self._initialized = true
end

-- Initialize hotkey configuration buttons
function SettingsWindow:initializeHotkeyButtons()
    self.hotkeyButtons = {}
    local hotkeys = HotkeyConfig.getAllHotkeys()
    local buttonHeight = 20
    local buttonSpacing = 5
    local hotkeyLabelHeight = 12
    local hotkeyButtonsHeight = #hotkeys * (buttonHeight + buttonSpacing) + hotkeyLabelHeight
    
    -- Layout: FPS (60px) + Mode (60px) + Resolution (60px) + Audio (180px) + Hotkeys + bottom padding
    local fpsHeight = 60
    local modeHeight = 60
    local resHeight = 60
    local audioHeight = 180
    local hotkeyStartY = 360  -- Start position for hotkey buttons
    local bottomPadding = 20
    local contentHeight = hotkeyStartY + hotkeyButtonsHeight + bottomPadding
    
    -- Initialize scroll handler
    self.scrollHandler = ScrollHandler:new()
    self.scrollHandler:initialize(self.position, self.width, self.height, contentHeight, function()
        self:updatePanelPositions()
    end)
    
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
    self.hotkeyPanel:initialize({x = x, y = y}, dropdownWidth, 0)  -- Will be updated in updatePanelPositions
    
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

-- Override setOpen
function SettingsWindow:setOpen(state)
    WindowBase.setOpen(self, state)
end

-- Get window open state
function SettingsWindow:getOpen()
    return self.isOpen
end

-- Main draw function
function SettingsWindow:draw()
    if not self.isOpen or not self.position then return end
    
    -- Draw semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.3 * self.animAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
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
    love.graphics.print("Hotkeys:", x + 30, y + 362 - scrollY)
    
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
    
    -- FIRST: Check for top bar dragging (must be before other checks)
    -- WindowBase handles its own coordinate conversion internally
    if WindowBase.mousepressed(self, mx, my, button) then
        return true
    end
    
    -- Convert screen coordinates to UI coordinates for UI element checks
    local uiMx, uiMy = Scaling.toUI(mx, my)
    
    -- Debug coordinate conversion (remove in production)
    -- print(string.format("Settings Mouse: raw(%d,%d) -> UI(%.1f,%.1f)", mx, my, uiMx, uiMy))
    
    -- Check Exit to Main Menu button (before any scrollable content)
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
    local uiMx, uiMy = Scaling.toUI(mx, my)
    
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
    local uiMx, uiMy = Scaling.toUI(mx, my)
    
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
            -- Panel positions will be updated automatically via callback
        end
        return true
    end
    
    return false
end

return SettingsWindow
