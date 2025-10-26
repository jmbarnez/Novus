---@diagnostic disable: undefined-global
-- Universal UI Window Base Module
-- Provides neon border, fade animation, elastic drag, and shared window logic

-- Review: This file is the likely base for all UI windows. Look for per-frame allocations, expensive draw logic, or unnecessary state changes. Check if draw() or update() methods allocate new tables, create canvases, or do expensive calculations every frame. Also check if any theme or batch renderer is called in a way that prevents batching or caching.

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
    o.animAlpha = 1
    o.animAlphaTarget = 1
    o.animAlphaSpeed = 0
    o.animAlphaActive = false
    o.isDragging = false
    o.dragOffset = {x = 0, y = 0}
    o.elasticityActive = false
    o.elasticityTarget = nil
    o.elasticityVelocity = {x = 0, y = 0}
    o.elasticitySpring = opts.elasticitySpring or 18
    o.elasticityDamping = opts.elasticityDamping or 0.7
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
    
    if state then
        self.animAlpha = 1
    else
        self.animAlpha = 0
    end
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
    -- No fade or sliding/elasticity: do nothing
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
function WindowBase:drawCloseButton(x, y, alpha)
    alpha = alpha or 1
    local border = 3
    local closeSize = 18
    local closeX = x + self.width - closeSize - 8 - border
    local closeY = y + border + (Theme.window.topBarHeight - 2*border - closeSize) / 2
    local mx, my = Scaling.toUI(love.mouse.getPosition())

    local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
    -- Minimal X: black by default, red on hover, no background
    local xColor = closeHover and {1,0.15,0.15,alpha} or {0,0,0,alpha}
    love.graphics.setLineWidth(2)
    love.graphics.setColor(xColor)
    love.graphics.line(closeX+4, closeY+4, closeX+closeSize-4, closeY+closeSize-4)
    love.graphics.line(closeX+closeSize-4, closeY+4, closeX+4, closeY+closeSize-4)
    love.graphics.setLineWidth(1)
    self.closeButtonRect = {x = closeX, y = closeY, w = closeSize, h = closeSize}
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

function WindowBase:draw()
    if not self.isOpen or not self.position then return end
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight
    local border = 3

    -- Draw window border
    love.graphics.setColor(1, 1, 1, 1)
    Theme.draw3DBorder(x, y, w, h)

    -- Divider line below top bar (thick plasma style)
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x+border, y+topBarH, x+w-border, y+topBarH)

    -- Divider line above bottom bar (thick plasma style)
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1)
    love.graphics.line(x+border, y+h-bottomBarH, x+w-border, y+h-bottomBarH)
    love.graphics.setLineWidth(1)
end

-- Helper for sign
function math.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return WindowBase
