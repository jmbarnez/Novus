-- UI Tooltips Module - Handles tooltip rendering with theme support
-- Displays item information on hover

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Tooltips = {}

-- Draw an item tooltip
function Tooltips.drawItemTooltip(itemId, itemDef, count, mouseX, mouseY)
    if not itemDef then return end
    
    -- Build tooltip lines
    local lines = {
        itemDef.name,
        "Count: " .. count,
    }
    if itemDef.value then
        table.insert(lines, "Value: " .. itemDef.value)
    end
    table.insert(lines, "Stackable: " .. (itemDef.stackable and "Yes" or "No"))
    table.insert(lines, "")
    table.insert(lines, itemDef.description)
    
    -- Calculate dimensions
    local font = Theme.getFont(Scaling.scaleSize(Theme.fonts.small))
    love.graphics.setFont(font)
    local lineHeight = Scaling.scaleSize(18)
    local maxWidth = 0
    
    for _, line in ipairs(lines) do
        local width = font:getWidth(line)
        maxWidth = math.max(maxWidth, width)
    end
    
    local padding = Scaling.scaleSize(Theme.spacing.padding)
    local tooltipW = maxWidth + padding * 2
    local tooltipH = #lines * lineHeight + padding * 2
    
    -- Position tooltip (offset from cursor)
    local tooltipX = Scaling.scaleX(mouseX) + Scaling.scaleX(12)
    local tooltipY = Scaling.scaleY(mouseY) + Scaling.scaleY(12)
    
    -- Keep within screen bounds
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    if tooltipX + tooltipW > screenW then
        tooltipX = Scaling.scaleX(mouseX) - tooltipW - Scaling.scaleX(12)
    end
    if tooltipY + tooltipH > screenH then
        tooltipY = Scaling.scaleY(mouseY) - tooltipH - Scaling.scaleY(12)
    end
    
    -- Draw background
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", tooltipX - Scaling.scaleX(2), tooltipY - Scaling.scaleY(2), tooltipW + Scaling.scaleX(4), tooltipH + Scaling.scaleY(4))
    
    -- Draw border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("line", tooltipX - Scaling.scaleX(2), tooltipY - Scaling.scaleY(2), tooltipW + Scaling.scaleX(4), tooltipH + Scaling.scaleY(4))
    
    -- Draw text
    love.graphics.setColor(Theme.colors.textPrimary)
    local textY = tooltipY + padding
    
    for i, line in ipairs(lines) do
        if i == 1 then
            -- Item name in accent color
            love.graphics.setColor(Theme.colors.textAccent)
        elseif line == "" then
            textY = textY + lineHeight
        else
            love.graphics.setColor(Theme.colors.textPrimary)
        end
        
        if line ~= "" then
            love.graphics.print(line, tooltipX + padding, textY)
            textY = textY + lineHeight
        end
    end
    
    love.graphics.setFont(Theme.getFont(Scaling.scaleSize(Theme.fonts.title)))
end

return Tooltips
