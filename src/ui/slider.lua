---@diagnostic disable: undefined-global
-- ============================================================================
-- Slider Component
-- ============================================================================
-- A horizontal slider UI component for adjusting numeric values

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Slider = {}
Slider.__index = Slider

function Slider:new(minValue, maxValue, currentValue, x, y, width, height, onChangeCallback)
    local self = setmetatable({}, Slider)
    
    self.minValue = minValue or 0
    self.maxValue = maxValue or 100
    self.currentValue = currentValue or self.minValue
    self.x = x or 0
    self.y = y or 0
    self.width = width or 200
    self.height = height or 20
    self.onChangeCallback = onChangeCallback
    
    -- Slider state
    self.isDragging = false
    self.dragOffset = 0
    
    return self
end

-- Update slider value
function Slider:setValue(value)
    self.currentValue = math.max(self.minValue, math.min(self.maxValue, value))
    if self.onChangeCallback then
        self.onChangeCallback(self.currentValue)
    end
end

-- Get current value
function Slider:getValue()
    return self.currentValue
end

-- Calculate thumb position based on current value
function Slider:getThumbPosition()
    local range = self.maxValue - self.minValue
    local normalizedValue = (self.currentValue - self.minValue) / range
    local thumbWidth = 16
    local trackWidth = self.width - thumbWidth
    return self.x + normalizedValue * trackWidth
end

-- Check if mouse is over the slider
function Slider:isMouseOver(mx, my)
    return mx >= self.x and mx <= self.x + self.width and
           my >= self.y and my <= self.y + self.height
end

-- Handle mouse press
function Slider:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    
    local isOver = self:isMouseOver(mx, my)
    if not isOver then return false end
    
    local thumbX = self:getThumbPosition()
    local thumbWidth = 16
    
    -- Check if clicking on thumb
    if mx >= thumbX and mx <= thumbX + thumbWidth then
        self.isDragging = true
        self.dragOffset = mx - thumbX
        return true
    else
        -- Click on track - jump to position
        local thumbWidth = 16
        local trackWidth = self.width - thumbWidth
        local relativeX = mx - self.x - thumbWidth / 2
        local normalizedX = math.max(0, math.min(1, relativeX / trackWidth))
        local newValue = self.minValue + normalizedX * (self.maxValue - self.minValue)
        self:setValue(newValue)
        return true
    end
end

-- Handle mouse release
function Slider:mousereleased(mx, my, button)
    if self.isDragging then
        self.isDragging = false
        return true
    end
    return false
end

-- Handle mouse move
function Slider:mousemoved(mx, my, dx, dy)
    if self.isDragging then
        local thumbWidth = 16
        local trackWidth = self.width - thumbWidth
        local relativeX = mx - self.x - self.dragOffset - thumbWidth / 2
        local normalizedX = math.max(0, math.min(1, relativeX / trackWidth))
        local newValue = self.minValue + normalizedX * (self.maxValue - self.minValue)
        self:setValue(newValue)
        return true
    end
    return false
end

-- Draw the slider
function Slider:draw(alpha)
    alpha = alpha or 1
    
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    local hovered = self:isMouseOver(mx, my)
    
    -- Draw track background
    love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], 
                          Theme.colors.bgMedium[3], alpha * 0.6)
    love.graphics.rectangle("fill", self.x, self.y + self.height/2 - 2, self.width, 4, 2, 2)
    
    -- Draw track border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], 
                          Theme.colors.borderMedium[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y + self.height/2 - 2, self.width, 4, 2, 2)
    
    -- Draw filled portion
    local thumbX = self:getThumbPosition()
    local fillWidth = thumbX - self.x + 8  -- Half thumb width
    if fillWidth > 0 then
        love.graphics.setColor(Theme.colors.buttonHover[1], Theme.colors.buttonHover[2], 
                              Theme.colors.buttonHover[3], alpha * 0.8)
        love.graphics.rectangle("fill", self.x, self.y + self.height/2 - 2, fillWidth, 4, 2, 2)
    end
    
    -- Draw thumb
    local thumbColor = (hovered or self.isDragging) and Theme.colors.buttonHover or Theme.colors.borderLight
    love.graphics.setColor(thumbColor[1], thumbColor[2], thumbColor[3], alpha)
    love.graphics.rectangle("fill", thumbX, self.y + self.height/2 - 8, 16, 16, 3, 3)
    
    -- Draw thumb border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], 
                          Theme.colors.borderMedium[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", thumbX, self.y + self.height/2 - 8, 16, 16, 3, 3)
    
    -- Draw value text
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], 
                          Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    local valueText = string.format("%.0f%%", self.currentValue)
    love.graphics.printf(valueText, self.x + self.width + 10, self.y + 2, 40, "left")
end

return Slider
