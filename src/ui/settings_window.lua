-- ============================================================================
-- Settings Window
-- ============================================================================
-- Provides a UI for adjusting game settings including:
--   - FPS limit (30, 60, 90, 120, 144, 240, Unlimited)
--   - Window mode (windowed, borderless, fullscreen)
--   - Resolution (when in windowed mode)
--   - Exit game button
--
-- This window extends WindowBase to inherit drag, close, and animation behaviors.
-- ============================================================================

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')

-- Create the settings window instance with default properties
local SettingsWindow = WindowBase:new{
    width = 460,                -- Window width in UI pixels
    height = 240,               -- Window height in UI pixels
    isOpen = false,             -- Initially closed
    animAlphaSpeed = 2.0,       -- Speed of fade in/out animation
    
    -- Button hitbox storage - these are initialized here to avoid race conditions
    -- where mousepressed() could be called before draw() creates them
    _fpsLeft = nil,             -- Left arrow button for FPS setting
    _fpsRight = nil,            -- Right arrow button for FPS setting
    _modeLeft = nil,            -- Left arrow button for window mode
    _modeRight = nil,           -- Right arrow button for window mode
    _resLeft = nil,             -- Left arrow button for resolution
    _resRight = nil,            -- Right arrow button for resolution
    _exitBtn = nil              -- Exit game button
}

-- ============================================================================
-- Window Mode Configuration
-- ============================================================================

-- Available window modes in order
SettingsWindow.modes = { 'windowed', 'borderless', 'fullscreen' }

--- Determines the current window mode index based on active flags
-- @return number Index into SettingsWindow.modes (1=windowed, 2=borderless, 3=fullscreen)
function SettingsWindow:currentModeIndex()
    local _, _, flags = love.window.getMode()
    if flags.fullscreen then return 3 end
    if flags.borderless and not flags.fullscreen then return 2 end
    return 1
end

-- ============================================================================
-- FPS Configuration
-- ============================================================================

-- Available FPS options (nil = unlimited)
SettingsWindow.fpsOptions = {30, 60, 90, 120, 144, 240, nil}
-- Labels for display (nil is shown as "Unlimited")
SettingsWindow.fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"}

--- Gets the current FPS setting's index in the fpsOptions array
-- @return number Index of the current FPS setting (defaults to unlimited if not found)
function SettingsWindow:currentFpsIndex()
    local curFps = TimeManager.getTargetFps()
    -- Search for matching FPS value
    for i,v in ipairs(self.fpsOptions) do
        if v == curFps then return i end
    end
    -- Default to "Unlimited" if current FPS doesn't match any preset
    return #self.fpsOptions
end

-- ============================================================================
-- Window State Management
-- ============================================================================

--- Toggles the window between open and closed states
function SettingsWindow:toggle()
    self:setOpen(not self.isOpen)
end

--- Gets the current open/closed state of the window
-- @return boolean True if window is open, false otherwise
function SettingsWindow:getOpen()
    return self.isOpen
end

-- ============================================================================
-- Drawing / Rendering
-- ============================================================================

--- Main draw function - renders the settings window and all its UI elements
-- This function:
--   1. Draws the window background (via WindowBase)
--   2. Updates button hitboxes (CRITICAL: must happen before mousepressed can use them)
--   3. Renders all UI elements (title, settings, buttons)
function SettingsWindow:draw()
    -- Early exit if window is closed or position not set
    if not self.isOpen or not self.position then return end
    
    -- Draw the base window (background, shadow, etc.)
    WindowBase.draw(self)
    
    -- Get window dimensions and animation state
    local x, y, w, h = self.position.x, self.position.y, self.width, self.height
    local alpha = self.animAlpha  -- Current fade in/out alpha value
    local spacing = Theme.spacing.padding
    
    -- ========================================================================
    -- Title Section
    -- ========================================================================
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Settings", x+10, y+6, w-20, "left")
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    
    -- ========================================================================
    -- FPS Limit Section
    -- ========================================================================
    local fpsIdx = self:currentFpsIndex()
    local fpsText = "FPS Limit: "..self.fpsLabels[fpsIdx]
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print(fpsText, x+spacing+10, y+50)
    
    -- IMPORTANT: Initialize button hitboxes here before they can be clicked
    -- This prevents the double-click issue where mousepressed() is called
    -- before draw() has a chance to set these values
    self._fpsLeft = { x=x+spacing+190, y=y+48, w=22, h=22 }
    self._fpsRight = { x=x+spacing+240, y=y+48, w=22, h=22 }
    
    -- Draw the FPS arrow buttons (left/right)
    love.graphics.setColor(0.7,0.85,1,alpha)
    love.graphics.rectangle('fill', self._fpsLeft.x, self._fpsLeft.y, 22, 22, 4,4)
    love.graphics.rectangle('fill', self._fpsRight.x, self._fpsRight.y, 22, 22, 4,4)
    love.graphics.setColor(0.2,0.2,0.3,alpha)
    love.graphics.printf('<', self._fpsLeft.x, self._fpsLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._fpsRight.x, self._fpsRight.y+2, 22, 'center')
    -- ========================================================================
    -- Window Mode Section
    -- ========================================================================
    local idx = self:currentModeIndex()
    local modeText = "Window Mode: ".. self.modes[idx]
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print(modeText, x+spacing+10, y+96)
    
    -- Initialize window mode button hitboxes
    self._modeLeft = { x=x+spacing+190, y=y+94, w=22, h=22 }
    self._modeRight = { x=x+spacing+240, y=y+94, w=22, h=22 }
    
    -- Draw the window mode arrow buttons
    love.graphics.setColor(0.7,0.85,1,alpha)
    love.graphics.rectangle('fill', self._modeLeft.x, self._modeLeft.y, 22, 22, 4,4)
    love.graphics.rectangle('fill', self._modeRight.x, self._modeRight.y, 22, 22, 4,4)
    love.graphics.setColor(0.2,0.2,0.3,alpha)
    love.graphics.printf('<', self._modeLeft.x, self._modeLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._modeRight.x, self._modeRight.y+2, 22, 'center')
    
    -- ========================================================================
    -- Resolution Section (only active in windowed mode)
    -- ========================================================================
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    
    -- Resolution controls are disabled when not in windowed mode
    local resDisable = (idx ~= 1)
    local resLblColor = resDisable and Theme.colors.textMuted or Theme.colors.textAccent
    
    love.graphics.setColor(resLblColor)
    local resSelIdx = self:getCurrentResIndex()
    local resText = "Resolution: "..self.resolutions[resSelIdx].label
    love.graphics.print(resText, x+spacing+10, y+122)
    
    -- Initialize resolution button hitboxes
    self._resLeft = { x=x+spacing+190, y=y+120, w=22, h=22 }
    self._resRight = { x=x+spacing+240, y=y+120, w=22, h=22 }
    
    -- Draw resolution arrow buttons (dimmed when disabled)
    love.graphics.setColor(resLblColor)
    love.graphics.rectangle('fill', self._resLeft.x, self._resLeft.y, 22, 22, 4, 4)
    love.graphics.rectangle('fill', self._resRight.x, self._resRight.y, 22, 22, 4, 4)
    love.graphics.setColor(0.2,0.2,0.3,alpha*0.9)
    love.graphics.printf('<', self._resLeft.x, self._resLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._resRight.x, self._resRight.y+2, 22, 'center')
    -- ========================================================================
    -- Exit Game Button
    -- ========================================================================
    local btnW, btnH = 140, 34
    local btnX = x + math.floor((w-btnW)/2)
    local btnY = y + h - Theme.window.bottomBarHeight - btnH - 10
    
    -- Initialize exit button hitbox
    self._exitBtn = {x=btnX, y=btnY, w=btnW, h=btnH}
    
    -- Check if mouse is hovering over exit button
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local hovered = mx >= btnX and mx <= btnX+btnW and my >= btnY and my <= btnY+btnH
    
    -- Draw exit button with hover effect
    love.graphics.setColor(hovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1,1,1,alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.printf('Exit Game', btnX, btnY+8, btnW, 'center')
    
    -- ========================================================================
    -- Close Button (X in top-right corner)
    -- ========================================================================
    self:drawCloseButton(x, y, alpha)
end

-- ============================================================================
-- Mouse Input Handling
-- ============================================================================

--- Handles mouse button presses within the settings window
-- @param mx Mouse X position in UI coordinates
-- @param my Mouse Y position in UI coordinates
-- @param button Mouse button number (1 = left, 2 = right, 3 = middle)
-- @return boolean|nil True if click was handled, nil otherwise
--
-- IMPORTANT: This function checks if button hitboxes exist before using them.
-- Previously, there was a race condition where mousepressed could be called
-- before draw() initialized the hitboxes, causing clicks to be missed.
-- Now hitboxes are initialized in draw() and checked here with 'if self._btn'.
function SettingsWindow:mousepressed(mx, my, button)
    -- Only handle left mouse button
    if button ~= 1 then return end
    
    -- ========================================================================
    -- Exit Game Button
    -- ========================================================================
    if self._exitBtn and 
       mx >= self._exitBtn.x and mx <= self._exitBtn.x + self._exitBtn.w and 
       my >= self._exitBtn.y and my <= self._exitBtn.y + self._exitBtn.h then
        love.event.quit()
        return true
    end
    
    -- ========================================================================
    -- FPS Limit Buttons
    -- ========================================================================
    -- Left arrow (decrease FPS limit)
    if self._fpsLeft and 
       mx >= self._fpsLeft.x and mx <= self._fpsLeft.x + self._fpsLeft.w and 
       my >= self._fpsLeft.y and my <= self._fpsLeft.y + self._fpsLeft.h then
        self:_changeFps(-1)
        return true
    -- Right arrow (increase FPS limit)
    elseif self._fpsRight and 
           mx >= self._fpsRight.x and mx <= self._fpsRight.x + self._fpsRight.w and 
           my >= self._fpsRight.y and my <= self._fpsRight.y + self._fpsRight.h then
        self:_changeFps(1)
        return true
    
    -- ========================================================================
    -- Window Mode Buttons
    -- ========================================================================
    -- Left arrow (previous window mode)
    elseif self._modeLeft and 
           mx >= self._modeLeft.x and mx <= self._modeLeft.x + self._modeLeft.w and 
           my >= self._modeLeft.y and my <= self._modeLeft.y + self._modeLeft.h then
        self:_changeMode(-1)
        return true
    -- Right arrow (next window mode)
    elseif self._modeRight and 
           mx >= self._modeRight.x and mx <= self._modeRight.x + self._modeRight.w and 
           my >= self._modeRight.y and my <= self._modeRight.y + self._modeRight.h then
        self:_changeMode(1)
        return true
    end
    
    -- ========================================================================
    -- Resolution Buttons (only active in windowed mode)
    -- ========================================================================
    local idx = self:currentModeIndex()
    local resDisable = (idx ~= 1)  -- Disabled unless windowed mode
    
    if not resDisable then
        -- Left arrow (previous resolution)
        if self._resLeft and 
           mx >= self._resLeft.x and mx <= self._resLeft.x + self._resLeft.w and 
           my >= self._resLeft.y and my <= self._resLeft.y + self._resLeft.h then
            local newIdx = self:getCurrentResIndex() - 1
            if newIdx < 1 then newIdx = #self.resolutions end  -- Wrap around
            self:setResolution(newIdx)
            return true
        -- Right arrow (next resolution)
        elseif self._resRight and 
               mx >= self._resRight.x and mx <= self._resRight.x + self._resRight.w and 
               my >= self._resRight.y and my <= self._resRight.y + self._resRight.h then
            local newIdx = self:getCurrentResIndex() + 1
            if newIdx > #self.resolutions then newIdx = 1 end  -- Wrap around
            self:setResolution(newIdx)
            return true
        end
    end
    
    -- If no button was clicked, pass to WindowBase for drag/close handling
    WindowBase.mousepressed(self, mx, my, button)
end

-- ============================================================================
-- Internal Helper Functions
-- ============================================================================

--- Changes the FPS limit setting
-- @param direction number Direction to change (-1 for previous, +1 for next)
function SettingsWindow:_changeFps(direction)
    local curIdx = self:currentFpsIndex()
    local nextIdx = curIdx + direction
    
    -- Wrap around if we go past the ends of the list
    if nextIdx < 1 then nextIdx = #self.fpsOptions end
    if nextIdx > #self.fpsOptions then nextIdx = 1 end
    
    -- Apply the new FPS limit via TimeManager
    local val = self.fpsOptions[nextIdx]
    TimeManager.setTargetFps(val)
end

-- Variables to store previous windowed dimensions (unused but kept for potential future use)
local prevWindowedW, prevWindowedH = love.graphics.getWidth(), love.graphics.getHeight()

--- Changes the window mode (windowed, borderless, fullscreen)
-- @param direction number Direction to change (-1 for previous, +1 for next)
function SettingsWindow:_changeMode(direction)
    local idx = self:currentModeIndex() + direction
    
    -- Wrap around if we go past the ends of the list
    if idx < 1 then idx = #self.modes end
    if idx > #self.modes then idx = 1 end
    
    local mode = self.modes[idx]
    
    -- Apply the appropriate window mode
    if mode == 'windowed' then
        -- Windowed mode with resizable borders
        local w, h, flags = love.window.getMode()
        love.window.setMode(w, h, {fullscreen=false, borderless=false, resizable=true})
    elseif mode == 'borderless' then
        -- Borderless fullscreen (covers screen but no exclusive fullscreen)
        local w, h = love.window.getDesktopDimensions and love.window.getDesktopDimensions() or {1920, 1080}
        love.window.setMode(w or 1920, h or 1080, {fullscreen=false, borderless=true, resizable=false})
    elseif mode == 'fullscreen' then
        -- True exclusive fullscreen mode
        local w, h = love.window.getDesktopDimensions and love.window.getDesktopDimensions() or {1920, 1080}
        love.window.setMode(w or 1920, h or 1080, {fullscreen=true, borderless=false, resizable=false})
    end
end

-- ============================================================================
-- Keyboard Input Handling
-- ============================================================================

--- Handles keyboard input for the settings window
-- @param key string The key that was pressed
function SettingsWindow:keypressed(key)
    -- Close window on Escape key
    if key == 'escape' then self:setOpen(false) end
end

-- ============================================================================
-- Additional Mouse Event Handlers
-- ============================================================================

--- Handles mouse button releases
-- Delegates to WindowBase for drag end handling
function SettingsWindow:mousereleased(mx, my, button)
    WindowBase.mousereleased(self, mx, my, button)
end

--- Handles mouse movement
-- Delegates to WindowBase for drag movement handling
function SettingsWindow:mousemoved(mx, my, dx, dy)
    WindowBase.mousemoved(self, mx, my, dx, dy)
end

-- ============================================================================
-- Resolution Configuration
-- ============================================================================

-- List of available resolution presets
SettingsWindow.resolutions = {
    {w = 1280, h = 720, label = "1280 x 720"},      -- 720p
    {w = 1600, h = 900, label = "1600 x 900"},      -- 900p
    {w = 1920, h = 1080, label = "1920 x 1080"},    -- 1080p (Full HD)
    {w = 2560, h = 1440, label = "2560 x 1440"},    -- 1440p (2K)
    {w = 3840, h = 2160, label = "3840 x 2160"}     -- 2160p (4K)
}

-- Default resolution index (3 = 1920x1080)
SettingsWindow.resIdx = 3

--- Gets the index of the current resolution in the resolutions list
-- Matches current window size to the closest resolution preset
-- @return number Index of the matching resolution (or default if no match)
function SettingsWindow:getCurrentResIndex()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Search for a resolution that matches (with tolerance of ±8 pixels)
    for i, r in ipairs(self.resolutions) do
        if math.abs(r.w-w)<=8 and math.abs(r.h-h)<=8 then 
            return i 
        end
    end
    
    -- Return stored index if no exact match found
    return self.resIdx
end

--- Sets the window resolution (only applies in windowed mode)
-- @param idx number Index into the resolutions table
function SettingsWindow:setResolution(idx)
    self.resIdx = idx
    local mIdx = self:currentModeIndex()
    
    -- Only change resolution directly when in windowed mode
    -- (other modes use desktop dimensions)
    if mIdx == 1 then
        local r = self.resolutions[idx]
        love.window.setMode(r.w, r.h, {fullscreen=false, borderless=false, resizable=true})
    end
end

-- ============================================================================
-- Module Export
-- ============================================================================

return SettingsWindow
