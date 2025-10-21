-- ============================================================================
-- Dropdown Menu Component
-- ============================================================================
-- A reusable dropdown component for selecting from a list of options.
-- Supports click-to-open/close and selection callbacks.

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Dropdown = {}
Dropdown.__index = Dropdown

--- Create a new dropdown instance
-- @param options table Array of option strings
-- @param selectedIndex number Current selection index (1-based)
-- @param x number Position X
-- @param y number Position Y
-- @param width number Width of dropdown
-- @param onSelect function Callback when selection changes: onSelect(newIndex, selectedValue)
-- @return table New dropdown instance
function Dropdown:new(options, selectedIndex, x, y, width, onSelect)
    local self = setmetatable({}, Dropdown)
    self.options = options
    self.selectedIndex = selectedIndex or 1
    self.x = x
    self.y = y
    self.width = width
    self.height = 28
    self.isOpen = false
    self.onSelect = onSelect
    self.itemHeight = 24
    return self
end

--- Get the currently selected option value
-- @return string The selected option
function Dropdown:getSelected()
    return self.options[self.selectedIndex]
end

--- Set the selected option by index
-- @param index number The new selection index
function Dropdown:setSelected(index)
    if index >= 1 and index <= #self.options then
        self.selectedIndex = index
    end
end

--- Draw the dropdown (combines button and menu)
-- @param alpha number Alpha for rendering (opacity)
function Dropdown:draw(alpha)
    self:drawClosed(alpha)
    if self.isOpen then
        self:drawOpen(alpha)
    end
end

--- Draw just the closed dropdown button
-- @param alpha number Alpha for rendering (opacity)
function Dropdown:drawClosed(alpha)
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    -- Draw closed dropdown button
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height, 4, 4)
    
    -- Highlight if hovering
    local isHovering = mx >= self.x and mx <= self.x + self.width and 
                      my >= self.y and my <= self.y + self.height and not self.isOpen
    if isHovering then
        love.graphics.setColor(Theme.colors.bgLight)
        love.graphics.rectangle('fill', self.x, self.y, self.width, self.height, 4, 4)
    end
    
    love.graphics.setColor(Theme.colors.borderMedium)
    love.graphics.rectangle('line', self.x, self.y, self.width, self.height, 4, 4)
    
    -- Draw selected text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local selectedText = self.options[self.selectedIndex] or "Select"
    love.graphics.printf(selectedText, self.x + 8, self.y + 4, self.width - 30, "left")
    
    -- Draw dropdown arrow
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.printf(self.isOpen and "^" or "v", self.x + self.width - 20, self.y + 4, 16, "center")
end

--- Draw just the open dropdown menu (no button)
-- @param alpha number Alpha for rendering (opacity)
function Dropdown:drawOpen(alpha)
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    local dropdownHeight = math.min(#self.options * self.itemHeight, 150)
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle('fill', self.x, self.y + self.height, self.width, dropdownHeight, 0, 0, 4, 4)
    
    love.graphics.setColor(Theme.colors.borderMedium)
    love.graphics.rectangle('line', self.x, self.y + self.height, self.width, dropdownHeight, 0, 0, 4, 4)
    
    -- Draw options
    for i, option in ipairs(self.options) do
        local optionY = self.y + self.height + (i - 1) * self.itemHeight
        if i > 5 then break end  -- Limit visible items
        
        local isSelected = i == self.selectedIndex
        local isItemHovering = mx >= self.x and mx <= self.x + self.width and 
                              my >= optionY and my <= optionY + self.itemHeight
        
        if isSelected then
            love.graphics.setColor(Theme.colors.bgLight)
            love.graphics.rectangle('fill', self.x, optionY, self.width, self.itemHeight)
        elseif isItemHovering then
            love.graphics.setColor(Theme.colors.bgMedium)
            love.graphics.rectangle('fill', self.x, optionY, self.width, self.itemHeight)
        end
        
        love.graphics.setColor(isSelected and Theme.colors.textAccent or Theme.colors.textPrimary)
        love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
        love.graphics.printf(option, self.x + 8, optionY + 2, self.width - 16, "left")
    end
end

--- Handle mouse click on dropdown
-- @param mx number Mouse X in UI coordinates
-- @param my number Mouse Y in UI coordinates
-- @return boolean True if click was handled
function Dropdown:mousepressed(mx, my)
    local buttonRect = {x = self.x, y = self.y, w = self.width, h = self.height}
    
    -- Check if clicking the button itself
    if mx >= buttonRect.x and mx <= buttonRect.x + buttonRect.w and 
       my >= buttonRect.y and my <= buttonRect.y + buttonRect.h then
        self.isOpen = not self.isOpen
        return true
    end
    
    -- Check if clicking an option while open
    if self.isOpen then
        for i = 1, math.min(#self.options, 5) do
            local optionY = self.y + self.height + (i - 1) * self.itemHeight
            if mx >= self.x and mx <= self.x + self.width and 
               my >= optionY and my <= optionY + self.itemHeight then
                self.selectedIndex = i
                self.isOpen = false
                if self.onSelect then
                    self.onSelect(i, self.options[i])
                end
                return true
            end
        end
    end
    
    -- Clicking outside closes dropdown
    if self.isOpen then
        self.isOpen = false
        return true
    end
    
    return false
end

return Dropdown
