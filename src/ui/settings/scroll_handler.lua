---@diagnostic disable: undefined-global
-- ============================================================================
-- Scroll Handler
-- ============================================================================
-- Handles scrolling functionality for settings window content

local Theme = require('src.ui.plasma_theme')

local ScrollHandler = {}

function ScrollHandler:new()
    local handler = {
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
        },
        position = {x = 0, y = 0},
        width = 0,
        height = 0,
        onScrollUpdate = nil  -- Callback function for scroll updates
    }
    setmetatable(handler, self)
    self.__index = self
    return handler
end

-- Initialize scroll handler
function ScrollHandler:initialize(position, width, height, contentHeight, onScrollUpdate)
    self.position = position
    self.width = width
    self.height = height
    self.contentHeight = contentHeight
    self.onScrollUpdate = onScrollUpdate
    
    -- Calculate scroll area dimensions
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight
    local contentAreaHeight = height - topBarH - 3 - 3 - bottomBarH  -- Available height for content (minus window borders)
    
    -- Calculate maximum scroll
    self.maxScrollY = math.max(0, contentHeight - contentAreaHeight)
    
    -- Initialize scroll bar
    self.scrollBar.x = position.x + width - 20
    self.scrollBar.y = position.y + topBarH + 3
    self.scrollBar.height = contentAreaHeight
    if contentHeight > 0 and contentHeight > contentAreaHeight then
        -- Calculate thumb height as proportion of visible area to total content
        self.scrollBar.thumbHeight = math.max(20, (contentAreaHeight / contentHeight) * contentAreaHeight)
        -- Initialize thumb position
        self.scrollBar.thumbY = self.scrollBar.y
    else
        -- No scrolling needed
        self.scrollBar.thumbHeight = contentAreaHeight
        self.scrollBar.thumbY = self.scrollBar.y
    end
end

-- Update scroll position
function ScrollHandler:updateScroll(deltaY)
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
    
    -- Call the scroll update callback if provided
    if self.onScrollUpdate then
        self.onScrollUpdate()
    end
end

-- Draw scroll bar
function ScrollHandler:draw(alpha)
    local sb = self.scrollBar
    local topBarH = Theme.window.topBarHeight

    -- Keep scroll bar metrics updated for scroll calculations, but skip rendering
    local contentAreaY = self.position.y + topBarH + 3
    local contentAreaH = self.height - topBarH - 3 - 3 - Theme.window.bottomBarHeight

    sb.x = self.position.x + self.width - 20
    sb.y = contentAreaY
    sb.height = contentAreaH
end

-- Handle scroll bar clicks
function ScrollHandler:handleScrollBarClick(mx, my)
    return false
end

-- Handle mouse move for scroll bar dragging
function ScrollHandler:mousemoved(mx, my, dx, dy)
    return false
end

-- Handle mouse release for scroll bar dragging
function ScrollHandler:mousereleased(mx, my, button)
    if self.scrollBar then
        self.scrollBar.dragging = false
    end
    return false
end

-- Handle mouse wheel scrolling
function ScrollHandler:wheelmoved(x, y, position, width, height)
    -- Check if mouse is over the settings window
    local mx, my = love.mouse.getPosition()
    if mx >= position.x and mx <= position.x + width and
       my >= position.y and my <= position.y + height then
        self:updateScroll(-y)  -- Invert scroll direction
        return true
    end
    return false
end

-- Get current scroll position
function ScrollHandler:getScrollY()
    return self.contentScrollY
end

-- Set scroll position
function ScrollHandler:setScrollY(y)
    self.contentScrollY = math.max(0, math.min(self.maxScrollY, y))
    if self.maxScrollY > 0 then
        self.scrollBar.thumbY = self.scrollBar.y + (self.contentScrollY / self.maxScrollY) * (self.scrollBar.height - self.scrollBar.thumbHeight)
    end
end

return ScrollHandler
