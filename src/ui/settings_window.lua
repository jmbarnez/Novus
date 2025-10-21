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
local HotkeyConfig = require('src.hotkey_config')

local SettingsWindow = WindowBase:new{
    width = 480,
    height = 400,
    isOpen = false,
    animAlphaSpeed = 2.0,
    
    -- Dropdown components
    fpsDropdown = nil,
    modeDropdown = nil,
    resDropdown = nil,
    _exitBtn = nil,
    _initialized = false,
    
    -- Hotkey configuration
    hotkeyButtons = {},
    selectedHotkey = nil,
    waitingForKey = false,
    
    -- Scrollable content
    contentScrollY = 0,
    maxScrollY = 0,
    contentHeight = 0,
    scrollBar = {
        x = 0,
        y = 0,
        width = 12,
        height = 0,
        thumbHeight = 0,
        thumbY = 0,
        dragging = false,
        dragOffset = 0
    }
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
    local contentAreaH = self.height - topBarH - 3 - 3 - 40
    
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
        
        love.graphics.setColor(thumbHovered and Theme.colors.buttonHover or Theme.colors.borderLight)
        love.graphics.rectangle("fill", sb.x + 1, sb.thumbY, sb.width - 2, sb.thumbHeight, 2, 2)
    end
end

-- Initialize dropdowns on first draw
function SettingsWindow:initialize()
    if self._initialized then return end
    
    -- Initialize scroll bar if not already done
    if not self.scrollBar then
        self.scrollBar = {
            x = 0,
            y = 0,
            width = 12,
            height = 0,
            thumbHeight = 0,
            thumbY = 0,
            dragging = false,
            dragOffset = 0
        }
    end
    
    -- Initialize scroll variables if not already done
    if not self.contentScrollY then
        self.contentScrollY = 0
    end
    if not self.maxScrollY then
        self.maxScrollY = 0
    end
    if not self.contentHeight then
        self.contentHeight = 0
    end
    
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
    
    -- Initialize hotkey buttons
    self:initializeHotkeyButtons()
    
    self._initialized = true
end

-- Initialize hotkey configuration buttons
function SettingsWindow:initializeHotkeyButtons()
    self.hotkeyButtons = {}
    local hotkeys = HotkeyConfig.getAllHotkeys()
    
    -- Calculate total content height
    local fpsHeight = 50
    local modeHeight = 50
    local resHeight = 50
    local hotkeyLabelHeight = 20
    local buttonHeight = 20
    local buttonSpacing = 5
    local hotkeyButtonsHeight = #hotkeys * (buttonHeight + buttonSpacing)
    local exitButtonHeight = 50
    local exitButtonPadding = 80
    
    self.contentHeight = fpsHeight + modeHeight + resHeight + hotkeyLabelHeight + hotkeyButtonsHeight + exitButtonHeight + exitButtonPadding
    
    -- Calculate scroll area dimensions
    local topBarH = Theme.window.topBarHeight
    local contentAreaHeight = self.height - topBarH - 3 - 3 - 40  -- Available height for content (minus window borders)
    
    -- Calculate maximum scroll
    self.maxScrollY = math.max(0, self.contentHeight - contentAreaHeight)
    
    -- Initialize scroll bar
    self.scrollBar.x = self.position.x + self.width - 20
    self.scrollBar.y = self.position.y + topBarH + 3
    self.scrollBar.height = contentAreaHeight
    if self.contentHeight > 0 then
        self.scrollBar.thumbHeight = math.max(20, contentAreaHeight * (contentAreaHeight / self.contentHeight))
        -- Initialize thumb position
        self.scrollBar.thumbY = self.scrollBar.y
    else
        self.scrollBar.thumbHeight = contentAreaHeight
        self.scrollBar.thumbY = self.scrollBar.y
    end
    
    for i, hotkey in ipairs(hotkeys) do
        table.insert(self.hotkeyButtons, {
            action = hotkey.action,
            description = hotkey.description,
            key = hotkey.key,
            x = self.position.x + 30,
            y = self.position.y + 220 + (i - 1) * (buttonHeight + buttonSpacing) - self.contentScrollY,
            width = self.width - 80,  -- Leave space for scroll bar
            height = buttonHeight
        })
    end
end

-- Update dropdown positions to match current window position
function SettingsWindow:updateDropdownPositions()
    if not self._initialized or not self.position then return end
    
    local x, y = self.position.x + 30, self.position.y + 60 - self.contentScrollY
    
    self.fpsDropdown.x = x
    self.fpsDropdown.y = y
    
    self.modeDropdown.x = x
    self.modeDropdown.y = y + 50
    
    self.resDropdown.x = x
    self.resDropdown.y = y + 100
    
    -- Update hotkey button positions
    local buttonHeight = 20
    local buttonSpacing = 5
    for i, button in ipairs(self.hotkeyButtons) do
        button.x = self.position.x + 30
        button.y = self.position.y + 220 + (i - 1) * (buttonHeight + buttonSpacing) - self.contentScrollY
        button.width = self.width - 80  -- Leave space for scroll bar
    end
    
    -- Update scroll bar position (will be updated in drawScrollBar)
    self.scrollBar.x = self.position.x + self.width - 20
    self.scrollBar.y = self.position.y + 20
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
    
    -- Draw glass overlay background
    love.graphics.setColor(0, 0, 0, 0.3 * self.animAlpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    WindowBase.draw(self)
    
    local x, y = self.position.x, self.position.y
    local alpha = self.animAlpha
    
    self:initialize()
    self:updateDropdownPositions()
    
    -- Title (always visible at top)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Settings", x + 10, y + 6, self.width - 20, "left")
    
    -- Set up scissor/clip region for scrollable content
    local topBarH = Theme.window.topBarHeight
    local contentAreaX = x + 3
    local contentAreaY = y + topBarH + 3
    local contentAreaW = self.width - 6 - 20  -- Leave space for scroll bar
    local contentAreaH = self.height - topBarH - 3 - 3 - 40  -- Account for bottom bar area
    
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)
    
    -- Labels (draw BEFORE dropdowns so they don't overlap)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.setColor(Theme.colors.textAccent)
    
    love.graphics.print("FPS Limit:", x + 30, y + 42 - self.contentScrollY)
    love.graphics.print("Window Mode:", x + 30, y + 92 - self.contentScrollY)
    love.graphics.print("Resolution:", x + 30, y + 142 - self.contentScrollY)
    love.graphics.print("Hotkeys:", x + 30, y + 202 - self.contentScrollY)
    
    -- Draw hotkey buttons (inside scissor region)
    self:drawHotkeyButtons(alpha)
    
    -- Draw closed dropdown buttons first (inside scissor region)
    self.fpsDropdown:drawClosed(alpha)
    self.modeDropdown:drawClosed(alpha)
    self.resDropdown:drawClosed(alpha)
    
    -- Disable scissor to draw dropdown menus outside clipping area
    love.graphics.setScissor()
    
    -- Draw open dropdown menus LAST so they render on top of everything else (without clipping)
    if self.fpsDropdown.isOpen then
        self.fpsDropdown:drawOpen(alpha)
    end
    if self.modeDropdown.isOpen then
        self.modeDropdown:drawOpen(alpha)
    end
    if self.resDropdown.isOpen then
        self.resDropdown:drawOpen(alpha)
    end
    
    -- Re-enable scissor for exit button
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)
    
    -- Exit Button (positioned at bottom of scrollable content)
    local btnW, btnH = 140, 34
    local btnX = x + (self.width - btnW) / 2
    -- Position button at the end of the scrollable content with more space
    local btnY = y + 42 + 50 + 50 + 20 + (#self.hotkeyButtons * 25) + 80 - self.contentScrollY
    
    self._exitBtn = {x = btnX, y = btnY, w = btnW, h = btnH}
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local hovered = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    
    love.graphics.setColor(hovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.printf('Exit Game', btnX, btnY + 8, btnW, 'center')
    
    -- Disable scissor
    love.graphics.setScissor()
    
    -- Close button
    self:drawCloseButton(x, y, alpha)
    
    -- Draw scroll bar (outside scissor, positioned on the side)
    self:drawScrollBar(alpha)
end

-- Mouse input
function SettingsWindow:mousepressed(mx, my, button)
    if button ~= 1 then return end
    
    if not self.isOpen then return end
    
    self:initialize()
    
    -- Try hotkey buttons first
    if self:handleHotkeyButtonClick(mx, my) then return end
    
    -- Try dropdowns
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

-- Handle hotkey button clicks
function SettingsWindow:handleHotkeyButtonClick(mx, my)
    if not self.hotkeyButtons then return false end
    
    -- Check if clicking on scroll bar thumb
    if not self.scrollBar then return false end
    
    local sb = self.scrollBar
    if mx >= sb.x and mx <= sb.x + sb.width and
       my >= sb.y and my <= sb.y + sb.height then
        
        if my >= sb.thumbY and my <= sb.thumbY + sb.thumbHeight then
            -- Start dragging scroll bar thumb
            self.scrollBar.dragging = true
            self.scrollBar.dragOffset = my - sb.thumbY
            return true
        else
            -- Click on scroll bar track - jump to position
            local relativeY = my - sb.y
            local scrollRatio = relativeY / sb.height
            self.contentScrollY = scrollRatio * self.maxScrollY
            self:updateScroll(0) -- Update positions
            return true
        end
    end
    
    -- Check hotkey buttons
    for i, button in ipairs(self.hotkeyButtons) do
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
function SettingsWindow:keypressed(key)
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
        for i, button in ipairs(self.hotkeyButtons) do
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

function SettingsWindow:mousereleased(mx, my, button)
    -- Stop scroll bar dragging
    if self.scrollBar and self.scrollBar.dragging then
        self.scrollBar.dragging = false
        return true
    end
    
    WindowBase.mousereleased(self, mx, my, button)
end

function SettingsWindow:mousemoved(mx, my, dx, dy)
    -- Handle scroll bar dragging
    if self.scrollBar and self.scrollBar.dragging then
        local sb = self.scrollBar
        local newThumbY = my - sb.dragOffset
        local relativeY = newThumbY - sb.y
        local scrollRatio = math.max(0, math.min(1, relativeY / (sb.height - sb.thumbHeight)))
        self.contentScrollY = scrollRatio * self.maxScrollY
        self:updateScroll(0) -- Update positions
        return true
    end
    
    WindowBase.mousemoved(self, mx, my, dx, dy)
end

-- Handle mouse wheel scrolling
function SettingsWindow:wheelmoved(x, y)
    if not self.isOpen then return false end
    
    -- Check if mouse is over the settings window
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    if mx >= self.position.x and mx <= self.position.x + self.width and
       my >= self.position.y and my <= self.position.y + self.height then
        self:updateScroll(-y)  -- Invert scroll direction
        return true
    end
    
    return false
end

return SettingsWindow
