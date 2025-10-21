local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local TimeManager = require('src.time_manager')

local SettingsWindow = WindowBase:new{
    width = 460,
    height = 240,
    isOpen = false,
    animAlphaSpeed = 2.0
}

SettingsWindow.modes = { 'windowed', 'borderless', 'fullscreen' }
function SettingsWindow:currentModeIndex()
    local _, _, flags = love.window.getMode()
    if flags.fullscreen then return 3 end
    if flags.borderless and not flags.fullscreen then return 2 end
    return 1
end
SettingsWindow.fpsOptions = {30, 60, 90, 120, 144, 240, nil} -- nil for Unlimited
SettingsWindow.fpsLabels = {"30", "60", "90", "120", "144", "240", "Unlimited"}

function SettingsWindow:currentFpsIndex()
    local curFps = TimeManager.getTargetFps()
    for i,v in ipairs(self.fpsOptions) do
        if v == curFps then return i end
    end
    -- Default to "Unlimited"
    return #self.fpsOptions
end

function SettingsWindow:toggle()
    self:setOpen(not self.isOpen)
end

function SettingsWindow:getOpen()
    return self.isOpen
end

function SettingsWindow:draw()
    if not self.isOpen or not self.position then return end
    WindowBase.draw(self)
    local x, y, w, h = self.position.x, self.position.y, self.width, self.height
    local alpha = self.animAlpha
    local spacing = Theme.spacing.padding
    -- Title
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.title))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf("Settings", x+10, y+6, w-20, "left")
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    -- FPS Limit
    local fpsIdx = self:currentFpsIndex()
    local fpsText = "FPS Limit: "..self.fpsLabels[fpsIdx]
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print(fpsText, x+spacing+10, y+50)
    -- Draw FPS change arrows/buttons
    self._fpsLeft = { x=x+spacing+190, y=y+48, w=22, h=22 }
    self._fpsRight = { x=x+spacing+240, y=y+48, w=22, h=22 }
    love.graphics.setColor(0.7,0.85,1,alpha)
    love.graphics.rectangle('fill', self._fpsLeft.x, self._fpsLeft.y, 22, 22, 4,4)
    love.graphics.rectangle('fill', self._fpsRight.x, self._fpsRight.y, 22, 22, 4,4)
    love.graphics.setColor(0.2,0.2,0.3,alpha)
    love.graphics.printf('<', self._fpsLeft.x, self._fpsLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._fpsRight.x, self._fpsRight.y+2, 22, 'center')
    -- Window Mode
    local idx = self:currentModeIndex()
    local modeText = "Window Mode: ".. self.modes[idx]
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print(modeText, x+spacing+10, y+96)
    -- Draw Mode change arrows/buttons
    self._modeLeft = { x=x+spacing+190, y=y+94, w=22, h=22 }
    self._modeRight = { x=x+spacing+240, y=y+94, w=22, h=22 }
    love.graphics.setColor(0.7,0.85,1,alpha)
    love.graphics.rectangle('fill', self._modeLeft.x, self._modeLeft.y, 22, 22, 4,4)
    love.graphics.rectangle('fill', self._modeRight.x, self._modeRight.y, 22, 22, 4,4)
    love.graphics.setColor(0.2,0.2,0.3,alpha)
    love.graphics.printf('<', self._modeLeft.x, self._modeLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._modeRight.x, self._modeRight.y+2, 22, 'center')
    -- Resolution selector (for windowed only)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local resDisable = (idx ~= 1)
    local resLblColor = resDisable and Theme.colors.textMuted or Theme.colors.textAccent
    love.graphics.setColor(resLblColor)
    local resSelIdx = self:getCurrentResIndex()
    local resText = "Resolution: "..self.resolutions[resSelIdx].label
    love.graphics.print(resText, x+spacing+10, y+122)
    self._resLeft = { x=x+spacing+190, y=y+120, w=22, h=22 }
    self._resRight = { x=x+spacing+240, y=y+120, w=22, h=22 }
    love.graphics.setColor(resLblColor)
    love.graphics.rectangle('fill', self._resLeft.x, self._resLeft.y, 22, 22, 4, 4)
    love.graphics.rectangle('fill', self._resRight.x, self._resRight.y, 22, 22, 4, 4)
    love.graphics.setColor(0.2,0.2,0.3,alpha*0.9)
    love.graphics.printf('<', self._resLeft.x, self._resLeft.y+2, 22, 'center')
    love.graphics.printf('>', self._resRight.x, self._resRight.y+2, 22, 'center')
    -- Exit Game button
    local btnW, btnH = 140, 34
    local btnX = x + math.floor((w-btnW)/2)
    local btnY = y + h - Theme.window.bottomBarHeight - btnH - 10
    self._exitBtn = {x=btnX, y=btnY, w=btnW, h=btnH}
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local hovered = mx >= btnX and mx <= btnX+btnW and my >= btnY and my <= btnY+btnH
    love.graphics.setColor(hovered and Theme.colors.buttonCloseHover or Theme.colors.buttonClose)
    love.graphics.rectangle('fill', btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1,1,1,alpha)
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
    love.graphics.printf('Exit Game', btnX, btnY+8, btnW, 'center')
    -- Close button (universal)
    self:drawCloseButton(x, y, alpha)
end

function SettingsWindow:mousepressed(mx, my, button)
    if button ~= 1 then return end
    -- Handle Exit Game button
    if self._exitBtn and mx >= self._exitBtn.x and mx <= self._exitBtn.x + self._exitBtn.w and my >= self._exitBtn.y and my <= self._exitBtn.y + self._exitBtn.h then
        love.event.quit()
        return true
    end
    if self._fpsLeft and mx >= self._fpsLeft.x and mx <= self._fpsLeft.x + self._fpsLeft.w and my >= self._fpsLeft.y and my <= self._fpsLeft.y + self._fpsLeft.h then
        self:_changeFps(-1)
        return true
    elseif self._fpsRight and mx >= self._fpsRight.x and mx <= self._fpsRight.x + self._fpsRight.w and my >= self._fpsRight.y and my <= self._fpsRight.y + self._fpsRight.h then
        self:_changeFps(1)
        return true
    elseif self._modeLeft and mx >= self._modeLeft.x and mx <= self._modeLeft.x + self._modeLeft.w and my >= self._modeLeft.y and my <= self._modeLeft.y + self._modeLeft.h then
        self:_changeMode(-1)
        return true
    elseif self._modeRight and mx >= self._modeRight.x and mx <= self._modeRight.x + self._modeRight.w and my >= self._modeRight.y and my <= self._modeRight.y + self._modeRight.h then
        self:_changeMode(1)
        return true
    end
    -- Resolution arrows are only active if not resDisable (i.e. windowed mode)
    local idx = self:currentModeIndex()
    local resDisable = (idx ~= 1)
    if not resDisable then
        if self._resLeft and mx >= self._resLeft.x and mx <= self._resLeft.x + self._resLeft.w and my >= self._resLeft.y and my <= self._resLeft.y + self._resLeft.h then
            local newIdx = self:getCurrentResIndex() - 1
            if newIdx < 1 then newIdx = #self.resolutions end
            self:setResolution(newIdx)
            return true
        elseif self._resRight and mx >= self._resRight.x and mx <= self._resRight.x + self._resRight.w and my >= self._resRight.y and my <= self._resRight.y + self._resRight.h then
            local newIdx = self:getCurrentResIndex() + 1
            if newIdx > #self.resolutions then newIdx = 1 end
            self:setResolution(newIdx)
            return true
        end
    end
    WindowBase.mousepressed(self, mx, my, button)
end

function SettingsWindow:_changeFps(direction)
    local curIdx = self:currentFpsIndex()
    local nextIdx = curIdx + direction
    if nextIdx < 1 then nextIdx = #self.fpsOptions end
    if nextIdx > #self.fpsOptions then nextIdx = 1 end
    local val = self.fpsOptions[nextIdx]
    TimeManager.setTargetFps(val)
end

local prevWindowedW, prevWindowedH = love.graphics.getWidth(), love.graphics.getHeight()
function SettingsWindow:_changeMode(direction)
    local idx = self:currentModeIndex() + direction
    if idx < 1 then idx = #self.modes end
    if idx > #self.modes then idx = 1 end
    local mode = self.modes[idx]
    if mode == 'windowed' then
        local w, h, flags = love.window.getMode()
        love.window.setMode(w, h, {fullscreen=false, borderless=false, resizable=true})
    elseif mode == 'borderless' then
        local w, h = love.window.getDesktopDimensions and love.window.getDesktopDimensions() or {1920, 1080}
        love.window.setMode(w or 1920, h or 1080, {fullscreen=false, borderless=true, resizable=false})
    elseif mode == 'fullscreen' then
        local w, h = love.window.getDesktopDimensions and love.window.getDesktopDimensions() or {1920, 1080}
        love.window.setMode(w or 1920, h or 1080, {fullscreen=true, borderless=false, resizable=false})
    end
end

function SettingsWindow:keypressed(key)
    if key == 'escape' then self:setOpen(false) end
end

function SettingsWindow:mousereleased(mx, my, button)
    WindowBase.mousereleased(self, mx, my, button)
end

function SettingsWindow:mousemoved(mx, my, dx, dy)
    WindowBase.mousemoved(self, mx, my, dx, dy)
end

SettingsWindow.resolutions = {
    {w = 1280, h = 720, label = "1280 x 720"},
    {w = 1600, h = 900, label = "1600 x 900"},
    {w = 1920, h = 1080, label = "1920 x 1080"},
    {w = 2560, h = 1440, label = "2560 x 1440"},
    {w = 3840, h = 2160, label = "3840 x 2160"}
}
SettingsWindow.resIdx = 3 -- default: 1920x1080 (changeable)
function SettingsWindow:getCurrentResIndex()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    for i, r in ipairs(self.resolutions) do
        if math.abs(r.w-w)<=8 and math.abs(r.h-h)<=8 then return i end
    end
    return self.resIdx
end
function SettingsWindow:setResolution(idx)
    self.resIdx = idx
    local mIdx = self:currentModeIndex()
    if mIdx == 1 then -- only change resolution directly in windowed mode
        local r = self.resolutions[idx]
        love.window.setMode(r.w, r.h, {fullscreen=false, borderless=false, resizable=true})
    end
end

return SettingsWindow
