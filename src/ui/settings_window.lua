---@diagnostic disable: undefined-global
-- ============================================================================
-- Settings Window with Dropdown Menus
-- ============================================================================
-- Provides a UI for adjusting game settings using dropdown menus:
--   - FPS limit dropdown
--   - Resolution dropdown (windowed mode only)
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
local Dropdown = require('src.ui.dropdown')
local Slider = require('src.ui.slider')

-- Import settings panels
local HotkeyConfigPanel = require('src.ui.settings.hotkey_config_panel')
local AudioSettingsPanel = require('src.ui.settings.audio_settings_panel')
local DisplaySettingsPanel = require('src.ui.settings.display_settings_panel')
local ScrollHandler = require('src.ui.settings.scroll_handler')

local SettingsWindow = WindowBase:new{
    width = 900,
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

-- Cache widget classes on the instance to avoid relying on globals when
-- constructing UI controls during initialization in gameplay builds where
-- strict global checking may be enabled.
SettingsWindow.dropdownClass = Dropdown

-- Canvas used to render a downscaled copy of the screen for a blur-like background
SettingsWindow._blurCanvas = nil
SettingsWindow._screenW = nil
SettingsWindow._screenH = nil

-- FPS Configuration
-- FPS options (nil means no cap / Unlimited)
SettingsWindow.fpsOptions = {30, 60, 90, 120, 144, 240, nil}
SettingsWindow.fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"}

-- Window mode is always windowed; dropdown removed

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
    local SoundSystem = require('src.systems.sound')
    self.savedSettings = {
        vsync = DisplayManager.isVsyncEnabled(),
        fps = TimeManager.getTargetFps(),
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
-- Window mode index logic removed (only windowed mode supported)

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
    
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    
    for i, button in ipairs(self.hotkeyButtons) do
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
        
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 4, 4)
        
        -- Button border
        love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2],
                             Theme.colors.borderAlt[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 4, 4)
        
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
    self:updatePanelPositions()
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
    love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2],
                          Theme.colors.surface[3], alpha * 0.8)
    love.graphics.rectangle("fill", sb.x, sb.y, sb.width, sb.height, 2, 2)
    
    -- Scroll bar border
    love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2],
                          Theme.colors.borderAlt[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sb.x, sb.y, sb.width, sb.height, 2, 2)
    
    -- Only draw thumb if there's scrollable content
    if self.maxScrollY > 0 then
        -- Scroll bar thumb
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
        local thumbHovered = mx >= sb.x and mx <= sb.x + sb.width and 
                            my >= sb.thumbY and my <= sb.thumbY + sb.thumbHeight
        
        if thumbHovered then
            love.graphics.setColor(Theme.colors.hover[1], Theme.colors.hover[2],
                                 Theme.colors.hover[3], alpha)
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
    
    -- Layout helpers (keep in sync with draw() so labels and controls align)
    local paddingX = Theme.spacing.sm * 5  -- Scaled padding
    local labelOffset = Theme.window.topBarHeight + Theme.spacing.sm * 3  -- Y offset for labels from window top
    local controlOffset = Theme.window.topBarHeight + Theme.spacing.sm * 4  -- Y offset for the first control from window top
    local sectionSpacing = Theme.spacing.sm * 10  -- Vertical spacing between control sections

    local x, y = self.position.x + paddingX, self.position.y + controlOffset
    local dropdownWidth = self.width - (paddingX * 2)
    
    -- FPS Dropdown
    local dropdownClass = self.dropdownClass or Dropdown

    self.fpsDropdown = dropdownClass:new(self.fpsLabels, self:currentFpsIndex(), x, y, dropdownWidth, function(idx, val)
        TimeManager.setTargetFps(self.fpsOptions[idx])
        self:saveSettingsSnapshot()
    end)
    
    -- Mode dropdown removed (window mode controlled by conf.lua)
    
    -- Resolution Dropdown
    local resLabels = {}
    for i, res in ipairs(self.resolutions) do
        table.insert(resLabels, res.label)
    end
    
    self.resDropdown = dropdownClass:new(
        resLabels,
        self:getCurrentResIndex(), 
        x, y + sectionSpacing * 2, 
        dropdownWidth, 
        function(idx, val)
            local res = self.resolutions[idx]
            if not res then return end

            RenderCanvas.setRenderResolution(res.w, res.h)

            -- Always apply windowed mode (only mode supported)
            DisplayManager.applyWindowMode('windowed', { width = res.w, height = res.h })

            self:saveSettingsSnapshot()
        end
    )
    
    -- Audio Volume Sliders
    self.masterVolumeSlider = Slider:new(
        self.volumeMin,
        self.volumeMax,
        self:getCurrentVolume("master"),
        x, y + sectionSpacing * 3,
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
        x, y + sectionSpacing * 4,
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
        x, y + sectionSpacing * 5,
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
    local buttonHeight = Theme.spacing.sm * 3.33  -- Scaled button height
    local buttonSpacing = Theme.spacing.sm  -- Scaled spacing
    local hotkeyLabelHeight = Theme.spacing.sm * 2  -- Scaled label height

    -- Calculate total hotkey buttons height including section headers
    local sectionHeaderHeight = buttonHeight * 0.8
    local yOffset = 0
    local lastSection = nil
    for i, hotkey in ipairs(hotkeys) do
        local section = HotkeyConfig.actionSections[hotkey.action] or "Other"
        if section ~= lastSection then
            yOffset = yOffset + sectionHeaderHeight + buttonSpacing
            lastSection = section
        end
        yOffset = yOffset + buttonHeight + buttonSpacing
    end
    local hotkeyButtonsHeight = yOffset + hotkeyLabelHeight

    -- Layout: VSync + FPS + Resolution + Audio + Hotkeys + bottom padding
    local vsyncHeight = Theme.spacing.sm * 10  -- Scaled VSync section height
    local fpsHeight = Theme.spacing.sm * 10  -- Scaled FPS section height
    local resHeight = Theme.spacing.sm * 10  -- Scaled resolution section height
    local audioHeight = Theme.spacing.sm * 30  -- Scaled audio section height
    local hotkeyStartY = vsyncHeight + fpsHeight + resHeight + audioHeight  -- Start position for hotkey buttons
    local bottomPadding = Theme.spacing.sm * 3.33  -- Scaled bottom padding

    -- Add extra bottom padding to ensure the scrollable content extends far enough
    -- so all hotkey entries can be reached on smaller screens / tighter layouts.
    local extraBottomPadding = Theme.spacing.sm * 12

    local contentHeight = hotkeyStartY + hotkeyButtonsHeight + bottomPadding + extraBottomPadding

    -- Ensure contentHeight is at least as tall as the window to avoid an unexpectedly
    -- small scrollable range on some layouts.
    if self.height and contentHeight < self.height then
        contentHeight = self.height
    end

    -- Define position and width variables for panel initialization
    local paddingX = Theme.spacing.sm * 5  -- Scaled padding
    local controlOffset = Theme.window.topBarHeight + Theme.spacing.sm * 4  -- Scaled control offset
    local x, y = self.position.x + paddingX, self.position.y + controlOffset
    local dropdownWidth = self.width - (paddingX * 2)
    
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
    
    local paddingX = Theme.spacing.sm * 5  -- Scaled padding
    local controlOffset = Theme.window.topBarHeight + Theme.spacing.sm * 4  -- Y offset for the first control from window top
    
    local x = self.position.x + paddingX
    local y = self.position.y + controlOffset
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
    if state then
        -- Ensure the window renders immediately when opened from the pause menu
        self.animAlpha = 1
        self.animAlphaActive = false
        if love and love.timer then
            self._lastAnimTimestamp = love.timer.getTime()
        end
    end
end

-- Get window open state
function SettingsWindow:getOpen()
    return self.isOpen
end

-- Main draw function
function SettingsWindow:draw()
    if not self:isVisible() then return end

    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end

    -- Draw semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.3 * alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    WindowBase.draw(self)
    if not self.position then return end

    local x, y = self.position.x, self.position.y
    
    self:initialize()
    self:updatePanelPositions()
    
    -- Title (always visible at top)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(unpack(Theme.colors.text))
    love.graphics.printf("Settings", x + 10, y + 6, self.width - 20, "left")
    -- Theme toggle icon button (dark/light) — placed fully inside the top bar
    do
        local btnW, btnH = 34, 20
        local padding = 12
        local closeBtnOffset = 35
        local closeBtnX = x + self.width - closeBtnOffset
        local btnX = closeBtnX - btnW - 8
        local topBarH = Theme.window.topBarHeight or 28
        local btnY = y + (topBarH - btnH) / 2
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
        local btnHovered = mx and (mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH)

        -- Draw button background using Theme.drawButton for consistent styling (empty label)
        Theme.drawButton(btnX, btnY, btnW, btnH, "", btnHovered, nil, nil, {font = Theme.getFont("sm")})

        -- Draw icon centered in button
        local iconCx = btnX + btnW / 2
        local iconCy = btnY + btnH / 2
        local r = math.min(btnW, btnH) * 0.28
        local currentVariant = Theme.variants.current or "dark"
        if currentVariant == "dark" then
            -- Moon (crescent)
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], (Theme.colors.text[4] or 1) * alpha)
            love.graphics.circle("fill", iconCx, iconCy, r)
            love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], (Theme.colors.surface[4] or 1) * alpha)
            love.graphics.circle("fill", iconCx + r * 0.45, iconCy - r * 0.2, r * 0.9)
        else
            -- Sun
            love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], (Theme.colors.accent[4] or 1) * alpha)
            love.graphics.circle("fill", iconCx, iconCy, r)
            love.graphics.setLineWidth(1)
            for i = 0, 7 do
                local a = i * (math.pi * 2 / 8)
                local x1 = iconCx + math.cos(a) * (r + 2)
                local y1 = iconCy + math.sin(a) * (r + 2)
                local x2 = iconCx + math.cos(a) * (r + 6)
                local y2 = iconCy + math.sin(a) * (r + 6)
                love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], (Theme.colors.accent[4] or 1) * alpha)
                love.graphics.line(x1, y1, x2, y2)
            end
        end
    end
    
    -- Set up scissor/clip region for scrollable content
    local topBarH = Theme.window.topBarHeight
    local contentAreaX = x + 3
    local contentAreaY = y + topBarH + 3
    local contentAreaW = self.width - 6
    local contentAreaH = self.height - topBarH - 3 - 3 - Theme.window.bottomBarHeight  -- Account for bottom bar area
    
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)
    
    -- Labels (draw BEFORE panels so they don't overlap)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(unpack(Theme.colors.accent))

    local scrollY = self.scrollHandler:getScrollY()
    local paddingX = Theme.spacing.sm * 5  -- Scaled padding
    local labelOffset = Theme.window.topBarHeight + Theme.spacing.sm * 3  -- Y offset for labels from window top
    local sectionSpacing = Theme.spacing.sm * 12  -- Vertical spacing between sections (increased for better alignment)

    local labelX = x + paddingX
    local baseLabelY = y + labelOffset - scrollY

    -- Draw labels aligned with controls
    love.graphics.print("VSync:", labelX, baseLabelY)
    love.graphics.print("FPS Limit:", labelX, baseLabelY + sectionSpacing)
    love.graphics.print("Resolution:", labelX, baseLabelY + sectionSpacing * 2)
    love.graphics.print("Master Volume:", labelX, baseLabelY + sectionSpacing * 3)
    love.graphics.print("Music Volume:", labelX, baseLabelY + sectionSpacing * 4)
    love.graphics.print("SFX Volume:", labelX, baseLabelY + sectionSpacing * 5)
    love.graphics.print("Hotkeys:", labelX, baseLabelY + sectionSpacing * 6)
    
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
    
    -- (Exit to Main Menu button removed)
    
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

    -- Theme toggle icon button click (top-right of window)
    do
        local btnW, btnH = 34, 20
        local padding = 12
        local closeBtnOffset = 35
        local closeBtnX = self.position.x + self.width - closeBtnOffset
        local btnX = closeBtnX - btnW - 8
        local topBarH = Theme.window.topBarHeight or 28
        local btnY = self.position.y + (topBarH - btnH) / 2
        if uiMx >= btnX and uiMx <= btnX + btnW and uiMy >= btnY and uiMy <= btnY + btnH then
            -- Toggle theme variant
            local current = Theme.variants.current or "dark"
            local next = (current == "dark") and "light" or "dark"
            Theme.setVariant(next)
            -- Save preference snapshot
            self:saveSettingsSnapshot()
            return true
        end
    end
    
    -- Debug coordinate conversion (remove in production)
    -- print(string.format("Settings Mouse: raw(%d,%d) -> UI(%.1f,%.1f)", mx, my, uiMx, uiMy))
    
    -- (Exit to Main Menu click handling removed)
    
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
    local uiMx, uiMy
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        uiMx, uiMy = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        uiMx, uiMy = Scaling.toUI(love.mouse.getPosition())
    end

    -- If an open dropdown is under the mouse, forward the wheel to it so it can scroll
    local function tryForward(dd)
        if not dd or not dd.isOpen then return false end
        local total = #dd.options
        local visibleCount = math.min(total, dd.maxVisible or 0)
        if visibleCount <= 0 then return false end
        local areaX = dd.x
        local areaY = dd.y + dd.height
        local areaW = dd.width
        local areaH = visibleCount * dd.itemHeight
        if uiMx >= areaX and uiMx <= areaX + areaW and uiMy >= areaY and uiMy <= areaY + areaH then
            if dd.wheelmoved then dd:wheelmoved(y, uiMx, uiMy) end
            return true
        end
        return false
    end

    if self.displayPanel and (
        tryForward(self.displayPanel.fpsDropdown) or
        tryForward(self.displayPanel.resDropdown)
    ) then
        return true
    end

    -- Otherwise, treat wheel as scrolling the settings window content
    if uiMx >= self.position.x and uiMx <= self.position.x + self.width and
       uiMy >= self.position.y and uiMy <= self.position.y + self.height then
        if self.scrollHandler then
            self.scrollHandler:updateScroll(-y)  -- Invert scroll direction
            -- Panel positions will be updated automatically via callback
        end
        return true
    end
    
    return false
end

return SettingsWindow
