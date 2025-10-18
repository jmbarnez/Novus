---@diagnostic disable: undefined-global
-- Universal UI Window Base Module
-- Provides neon border, fade animation, elastic drag, and shared window logic

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local WindowBase = {}
WindowBase.__index = WindowBase

function WindowBase:new(opts)
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
    return o
end

function WindowBase:setOpen(state)
    self.isOpen = state
    
    -- Center window on first open if not explicitly positioned
    if state and not self.positionInitialized and not self.position then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        self.position = {
            x = math.floor((screenW - self.width) / 2),
            y = math.floor((screenH - self.height) / 2)
        }
        self.positionInitialized = true
    end
    
    if state then
        self.animAlpha = 1
    else
        self.animAlpha = 0
    end
end

function WindowBase:update(dt)
    -- No fade or sliding/elasticity: do nothing
end

function WindowBase:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end
    local mx, my = x, y
    if mx >= self.position.x and mx <= self.position.x + self.width
       and my >= self.position.y and my <= self.position.y + Theme.window.topBarHeight and button == 1 then
        self.isDragging = true
        self.dragOffset.x = mx - self.position.x
        self.dragOffset.y = my - self.position.y
    end
end

function WindowBase:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end
end

function WindowBase:mousemoved(x, y, dx, dy)
    if self.isDragging and self.position then
        local mx, my = x, y
        self.position.x = mx - self.dragOffset.x
        self.position.y = my - self.dragOffset.y
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

    -- ...existing code...

    -- Divider line below top bar
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1)
    love.graphics.line(x+border, y+topBarH, x+w-border, y+topBarH)

    -- Divider line above bottom bar
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1)
    love.graphics.line(x+border, y+h-bottomBarH, x+w-border, y+h-bottomBarH)
end

-- Helper for sign
function math.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return WindowBase
