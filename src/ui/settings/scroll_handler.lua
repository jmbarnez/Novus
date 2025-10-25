---@diagnostic disable: undefined-global
-- ============================================================================
-- Scroll Handler
-- ============================================================================
-- Handles scrolling functionality for settings window content

local Theme = require('src.ui.theme')

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
    
    -- Position scroll bar within content area only
    local contentAreaY = self.position.y + topBarH + 3
    local contentAreaH = self.height - topBarH - 3 - 3 - Theme.window.bottomBarHeight
    
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
        local mx, my = love.mouse.getPosition()
        local thumbHovered = mx >= sb.x and mx <= sb.x + sb.width and 
                            my >= sb.thumbY and my <= sb.thumbY + sb.thumbHeight
        
        if thumbHovered then
            love.graphics.setColor(Theme.colors.buttonHover[1], Theme.colors.buttonHover[2], 
                                 Theme.colors.buttonHover[3], alpha)
        else
            love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], 
                                 Theme.colors.borderLight[3], alpha)
        end
        love.graphics.rectangle("fill", sb.x + 1, sb.thumbY, sb.width - 2, sb.thumbHeight, 2, 2)
    end
end

-- Handle scroll bar clicks
function ScrollHandler:handleScrollBarClick(mx, my)
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
            
            -- Update scroll bar thumb position
            self.scrollBar.thumbY = self.scrollBar.y + (self.contentScrollY / self.maxScrollY) * (self.scrollBar.height - self.scrollBar.thumbHeight)
            
            -- Call the scroll update callback if provided
            if self.onScrollUpdate then
                self.onScrollUpdate()
            end
            return true
        end
    end
    
    return false
end

-- Handle mouse move for scroll bar dragging
function ScrollHandler:mousemoved(mx, my, dx, dy)
    if self.scrollBar and self.scrollBar.dragging then
        local sb = self.scrollBar
        local newThumbY = my - sb.dragOffset
        local relativeY = newThumbY - sb.y
        local scrollRatio = math.max(0, math.min(1, relativeY / (sb.height - sb.thumbHeight)))
        self.contentScrollY = scrollRatio * self.maxScrollY
        
        -- Update scroll bar thumb position
        self.scrollBar.thumbY = self.scrollBar.y + (self.contentScrollY / self.maxScrollY) * (self.scrollBar.height - self.scrollBar.thumbHeight)
        
        -- Call the scroll update callback if provided
        if self.onScrollUpdate then
            self.onScrollUpdate()
        end
        return true
    end
    return false
end

-- Handle mouse release for scroll bar dragging
function ScrollHandler:mousereleased(mx, my, button)
    if self.scrollBar and self.scrollBar.dragging then
        self.scrollBar.dragging = false
        return true
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
