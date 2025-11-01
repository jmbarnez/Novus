---@diagnostic disable: undefined-global
-- Universal UI Window Base Module
-- Provides neon border, fade animation, elastic drag, and shared window logic

local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local Timer = love and love.timer or nil

local WindowBase = {}
WindowBase.__index = WindowBase

function WindowBase:new(opts)
    opts = opts or {}
    local o = setmetatable({}, self)
    o.position = opts.position or nil  -- Will be centered on first open if nil
    o.width = opts.width or 400
    o.height = opts.height or 300
    o.isOpen = opts.isOpen or false
    o.animAlphaSpeed = opts.animAlphaSpeed or 6
    o.animAlpha = o.isOpen and 1 or 0
    o.animAlphaActive = false
    o._lastAnimTimestamp = Timer and Timer.getTime() or nil
    o.isDragging = false
    o.dragOffset = {x = 0, y = 0}
    -- Elasticity/animation removed: windows are static and non-animated
    o.positionInitialized = false  -- Track if position has been centered
    o.autoCenter = opts.position == nil
    o.userMoved = false
    return o
end

function WindowBase:setOpen(state)
    state = not not state
    if self.isOpen == state then
        if state and ((not self.positionInitialized and not self.position) or (self.autoCenter and not self.userMoved)) then
            self:centerOnScreen()
        end
        return
    end

    self.isOpen = state
    
    -- Center window if it has no explicit position or has not yet been initialized
    if state then
        if (not self.positionInitialized and not self.position) or (self.autoCenter and not self.userMoved) then
            self:centerOnScreen()
        end
    end
    
    -- Trigger fade effect when state changes
    self.animAlphaActive = true
    self._lastAnimTimestamp = Timer and Timer.getTime() or nil
end

function WindowBase:getOpen()
    return self.isOpen
end

function WindowBase:toggle()
    self:setOpen(not self.isOpen)
end

function WindowBase:centerOnScreen(screenW, screenH)
    screenW = screenW or Scaling.getCurrentWidth()
    screenH = screenH or Scaling.getCurrentHeight()
    local w = self.width or 0
    local h = self.height or 0
    local x = math.floor(((screenW or 0) - w) / 2)
    local y = math.floor(((screenH or 0) - h) / 2)
    if x ~= x then x = 0 end -- handle NaN
    if y ~= y then y = 0 end
    self.position = {
        x = math.max(0, x),
        y = math.max(0, y)
    }
    self.positionInitialized = true
end

function WindowBase:onResize(screenW, screenH)
    if not self.position then return end
    local uiWidth = Scaling.getCurrentWidth()
    local uiHeight = Scaling.getCurrentHeight()

    -- Always re-center auto-centered windows that haven't been manually moved
    if self.autoCenter and not self.userMoved then
        self:centerOnScreen(uiWidth, uiHeight)
        return
    end

    -- For manually positioned windows, check if they're still valid
    local maxX = math.max(0, uiWidth - (self.width or 0))
    local maxY = math.max(0, uiHeight - (self.height or 0))

    -- If window is completely off-screen or in an invalid position, re-center it
    if self.position.x > maxX or self.position.y > maxY or
       self.position.x < -self.width * 0.5 or self.position.y < -self.height * 0.5 then
        self:centerOnScreen(uiWidth, uiHeight)
        self.userMoved = false -- Reset userMoved since we're auto-repositioning
        return
    end

    -- Otherwise, just clamp to valid bounds
    self.position.x = math.max(0, math.min(self.position.x or 0, maxX))
    self.position.y = math.max(0, math.min(self.position.y or 0, maxY))
end

local function advanceAnimation(self, dt)
    if not dt or dt <= 0 then
        if Timer then
            self._lastAnimTimestamp = Timer.getTime()
        end
        return
    end

    local target = self.isOpen and 1 or 0
    local alpha = self.animAlpha or 0
    if math.abs(alpha - target) < 0.001 then
        self.animAlpha = target
        self.animAlphaActive = false
        if Timer then
            self._lastAnimTimestamp = Timer.getTime()
        end
        return
    end

    local speed = self.animAlphaSpeed or 6
    local delta = dt * speed

    if alpha < target then
        alpha = math.min(target, alpha + delta)
    else
        alpha = math.max(target, alpha - delta)
    end

    self.animAlpha = alpha
    self.animAlphaActive = math.abs(alpha - target) >= 0.001
    if Timer then
        self._lastAnimTimestamp = Timer.getTime()
    end
end

function WindowBase:update(dt)
    if not self.animAlphaActive then
        return
    end
    advanceAnimation(self, dt or 0)
end

function WindowBase:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end
    -- x, y are already in UI coordinates when called from UI system
    local mx, my = x, y
    -- Close button handling (if present)
    if self.closeButtonRect and button == 1 then
        if mx >= self.closeButtonRect.x and mx <= self.closeButtonRect.x + self.closeButtonRect.w
           and my >= self.closeButtonRect.y and my <= self.closeButtonRect.y + self.closeButtonRect.h then
            self:setOpen(false)
            return
        end
    end
    if mx >= self.position.x and mx <= self.position.x + self.width
       and my >= self.position.y and my <= self.position.y + Theme.window.topBarHeight and button == 1 then
        self.isDragging = true
        self.dragOffset.x = mx - self.position.x
        self.dragOffset.y = my - self.position.y
    end
end

-- Default close button drawing for all windows
function WindowBase:drawCloseButton(x, y, alpha, mx, my)
    alpha = alpha or 1
    local topBarH = Theme.window.topBarHeight or 0
    if topBarH <= 0 then return end

    local padding = 6
    local buttonSize = math.max(16, topBarH - padding * 2)
    local closeX = x + self.width - buttonSize - padding
    local closeY = y + padding

    if not mx or not my then
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
    end

    local closeHover = mx >= closeX and mx <= closeX + buttonSize and my >= closeY and my <= closeY + buttonSize

    local font = Theme.getFontBold(Theme.fonts.title)
    love.graphics.setFont(font)
    local textColor = closeHover and Theme.colors.closeHover or Theme.colors.text
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * alpha)
    local textHeight = font:getHeight()
    local textYOffset = (buttonSize - textHeight) / 2
    love.graphics.printf("X", closeX, closeY + textYOffset, buttonSize, "center")

    self.closeButtonRect = {x = closeX, y = closeY, w = buttonSize, h = buttonSize}
end

function WindowBase:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end
end

function WindowBase:mousemoved(x, y, dx, dy)
    if self.isDragging and self.position then
        -- x, y are already in UI coordinates when called from UI system
        local newX = x - self.dragOffset.x
        local newY = y - self.dragOffset.y
        
        -- Clamp position to keep window on screen
        local uiWidth = Scaling.getCurrentWidth()
        local uiHeight = Scaling.getCurrentHeight()
        local maxX = math.max(0, uiWidth - (self.width or 0))
        local maxY = math.max(0, uiHeight - (self.height or 0))
        
        self.position.x = math.max(0, math.min(newX, maxX))
        self.position.y = math.max(0, math.min(newY, maxY))
        self.userMoved = true
    end
end

function WindowBase:keypressed(key)
    -- Default: windows don't consume key presses
    return false
end

function WindowBase:textinput(t)
    -- Default: windows don't consume text input
    return false
end

function WindowBase:isVisible()
    if self.isOpen then
        return true
    end
    local alpha = self.animAlpha or 0
    return alpha > 0.001 or self.animAlphaActive
end

function WindowBase:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    if self.animAlphaActive and Timer then
        local now = Timer.getTime()
        local last = self._lastAnimTimestamp or now
        local dt = now - last
        if dt > 0 then
            advanceAnimation(self, dt)
        elseif dt < 0 then
            self._lastAnimTimestamp = now
        end
    end

    if (not self:isVisible()) or not self.position then return end

    love.graphics.push('all')

    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight or 0
    local bottomBarH = Theme.window.bottomBarHeight or 0
    local radius = Theme.window.cornerRadius or 0
    local alpha = self.animAlpha or 1

    if alpha <= 0 then
        love.graphics.pop()
        return
    end

    local function setColor(color, multiplier)
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * (multiplier or 1))
    end

    -- Soft shadow (subtle, multi-pass rectangle expansion) using elevation tokens
    local function drawPanelShadow(px, py, pw, ph, pr, elev, baseAlpha)
        elev = elev or (Theme.elevation and Theme.elevation.low) or 2
        baseAlpha = baseAlpha or 0.28
        for i = 1, elev do
            local mul = (1 - (i - 1) / (elev + 1)) * 0.6
            local inset = i
            local a = baseAlpha * mul * alpha
            local shadowColor = Theme.colors.outlineBlack or {0, 0, 0, 1}
            love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], a)
            love.graphics.rectangle('fill', px - inset, py - inset, pw + inset * 2, ph + inset * 2, (pr or 0) + inset, (pr or 0) + inset)
        end
    end

    -- Panel background matching the pause menu styling
    -- Draw subtle shadow first so it sits under the panel
    pcall(function()
        local elev = (Theme.elevation and Theme.elevation.low) or 2
        drawPanelShadow(x, y, w, h, radius, elev, 0.28)
    end)
    setColor(Theme.colors.surface, 0.95)
    love.graphics.rectangle('fill', x, y, w, h, radius, radius)

    -- Header strip (mirrors pause menu header treatment)
    if topBarH > 0 then
        setColor(Theme.colors.surfaceAlt, 0.95)
        love.graphics.rectangle('fill', x, y, w, topBarH, radius, radius)
        setColor(Theme.colors.borderLight, 0.7)
        love.graphics.rectangle('fill', x, y + topBarH - 2, w, 2)
    end

    -- Footer strip for action rows / status text
    if bottomBarH > 0 then
        setColor(Theme.colors.surfaceAlt, 0.85)
        love.graphics.rectangle('fill', x, y + h - bottomBarH, w, bottomBarH, radius, radius)
        setColor(Theme.colors.borderLight, 0.5)
        love.graphics.rectangle('fill', x, y + h - bottomBarH, w, 2)
    end

    -- Primary border drawn last so it sits above header/footer fills
    setColor(Theme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, y, w, h, radius, radius)
    love.graphics.setLineWidth(1)

    love.graphics.pop()
end

-- Helper for sign
function math.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return WindowBase
