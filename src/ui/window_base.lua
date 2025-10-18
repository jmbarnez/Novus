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
    if x >= self.position.x and x <= self.position.x + self.width
       and y >= self.position.y and y <= self.position.y + Theme.window.topBarHeight and button == 1 then
        self.isDragging = true
        self.dragOffset.x = x - self.position.x
        self.dragOffset.y = y - self.position.y
    end
end

function WindowBase:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end
end

function WindowBase:mousemoved(x, y, dx, dy)
    if self.isDragging and self.position then
        self.position.x = x - self.dragOffset.x
        self.position.y = y - self.dragOffset.y
    end
end

function WindowBase:draw()
    if not self.isOpen or not self.position then return end
    local x = Scaling.scaleX(self.position.x)
    local y = Scaling.scaleY(self.position.y)
    local w = Scaling.scaleSize(self.width)
    local h = Scaling.scaleSize(self.height)
    love.graphics.setColor(1, 1, 1, 1)
    Theme.draw3DBorder(x, y, w, h)
    -- Additional universal window drawing can use scaled values (e.g. top bar)
end

-- Helper for sign
function math.sign(x)
    return (x > 0 and 1) or (x < 0 and -1) or 0
end

return WindowBase
