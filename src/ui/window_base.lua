---@diagnostic disable: undefined-global
-- Universal UI Window Base Module
-- Provides neon border, fade animation, elastic drag, and shared window logic

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local WindowBase = {}
WindowBase.__index = WindowBase

function WindowBase:new(opts)
    opts = opts or {}
    local o = setmetatable({}, self)
    o.position = opts.position or nil  -- Will be centered on first open if nil
    o.width = opts.width or 400
    o.height = opts.height or 300
    o.isOpen = opts.isOpen or false
    -- Animations removed: keep static alpha for compatibility
    o.animAlpha = 1
    o.animAlphaActive = false
    o.isDragging = false
    o.dragOffset = {x = 0, y = 0}
    -- Elasticity/animation removed: windows are static and non-animated
    o.positionInitialized = false  -- Track if position has been centered
    o.autoCenter = opts.position == nil
    o.userMoved = false
    return o
end

function WindowBase:setOpen(state)
    self.isOpen = state
    
    -- Center window if it has no explicit position or has not yet been initialized
    if state then
        if (not self.positionInitialized and not self.position) or (self.autoCenter and not self.userMoved) then
            self:centerOnScreen()
        end
    end
    
    -- No fade animations: open/close is immediate
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

function WindowBase:update(dt)
    -- Animations removed; nothing to update per-frame
end

function WindowBase:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end
    local mx, my = Scaling.toUI(x, y)
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
    local border = 3
    local closeSize = 18
    local closePadding = 6
    local closeX = x + self.width - closeSize - closePadding - border
    local closeY = y + border + (Theme.window.topBarHeight - 2*border - closeSize) / 2

    -- Use provided mouse coords if passed in (to avoid repeated calls per window)
    if not mx or not my then
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
    end

    local closeHover = mx >= closeX - 4 and mx <= closeX + closeSize + 4 and my >= closeY - 2 and my <= closeY + closeSize + 6

    local function setColor(color, multiplier)
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * (multiplier or 1))
    end

    local backX = closeX - 6
    local backY = closeY - 4
    local backW = closeSize + 12
    local backH = closeSize + 8

    -- Plasma tinted backdrop behind the X
    setColor(Theme.colors.buttonClose, closeHover and 0.7 or 0.35)
    love.graphics.rectangle('fill', backX, backY, backW, backH, 6, 6)

    setColor(Theme.colors.borderDark, closeHover and 0.9 or 0.6)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle('line', backX, backY, backW, backH, 6, 6)

    local xColor = closeHover and Theme.colors.buttonCloseHover or Theme.colors.textPrimary
    setColor(xColor, closeHover and 1.0 or 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(closeX + 4, closeY + 4, closeX + closeSize - 4, closeY + closeSize - 4)
    love.graphics.line(closeX + closeSize - 4, closeY + 4, closeX + 4, closeY + closeSize - 4)
    love.graphics.setLineWidth(1)

    self.closeButtonRect = {x = backX, y = backY, w = backW, h = backH}
end

function WindowBase:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end
end

function WindowBase:mousemoved(x, y, dx, dy)
    if self.isDragging and self.position then
        local mx, my = Scaling.toUI(x, y)
        self.position.x = mx - self.dragOffset.x
        self.position.y = my - self.dragOffset.y
        self.userMoved = true
    end
end

function WindowBase:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.isOpen or not self.position then return end

    love.graphics.push('all')

    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight
    local radius = Theme.window.cornerRadius or 0
    local padding = Theme.window.framePadding or 6
    local alpha = self.animAlpha or 1

    local function setColor(color, multiplier)
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * (multiplier or 1))
    end

    -- Clean boxy frame
    Theme.draw3DBorder(x, y, w, h, Theme.window.borderThickness, {
        alpha = alpha,
        cornerRadius = radius,
    })

    -- Soft interior glow to keep the sci-fi look consistent with the pause menu
    if w > padding * 2 and h > padding * 2 then
        setColor(Theme.colors.highlightBright, 0.6)
        love.graphics.rectangle(
            'line',
            x + padding,
            y + padding,
            w - padding * 2,
            h - padding * 2,
            math.max(0, radius - padding),
            math.max(0, radius - padding)
        )
    end

    -- Top bar background & accent line
    if topBarH and topBarH > 0 then
        local barHeight = math.max(0, topBarH - 4)
        setColor(Theme.colors.bgMedium, 0.95)
        love.graphics.rectangle('fill', x + 4, y + 4, w - 8, barHeight, math.max(0, radius - 4), math.max(0, radius - 4))

        if w > 24 then
            setColor(Theme.colors.borderNeon, 0.65)
            love.graphics.rectangle('fill', x + 12, y + topBarH - 2, w - 24, 2, 1, 1)
        end

        if w > 8 then
            setColor(Theme.colors.highlightBright, 1.1)
            love.graphics.rectangle('fill', x + 4, y + 4, w - 8, 2, math.max(0, radius - 4), math.max(0, radius - 4))
        end
    end

    -- Bottom bar background & accent line
    if bottomBarH and bottomBarH > 0 then
        local barHeight = math.max(0, bottomBarH - 4)
        setColor(Theme.colors.bgMedium, 0.9)
        love.graphics.rectangle(
            'fill',
            x + 4,
            y + h - bottomBarH,
            w - 8,
            barHeight,
            math.max(0, radius - 4),
            math.max(0, radius - 4)
        )

        if w > 24 then
            setColor(Theme.colors.borderNeon, 0.35)
            love.graphics.rectangle('fill', x + 12, y + h - bottomBarH + 2, w - 24, 2, 1, 1)
        end
    end

    love.graphics.pop()
end

-- Helper for sign
function math.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return WindowBase
