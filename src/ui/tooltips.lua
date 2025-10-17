-- UI Tooltips Module - Handles tooltip rendering with theme support
-- Displays item information on hover

local Theme = require('src.ui.theme')

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
    local font = Theme.getFont(Theme.fonts.small)
    love.graphics.setFont(font)
    local lineHeight = 18
    local maxWidth = 0
    
    for _, line in ipairs(lines) do
        local width = font:getWidth(line)
        maxWidth = math.max(maxWidth, width)
    end
    
    local padding = Theme.spacing.padding
    local tooltipW = maxWidth + padding * 2
    local tooltipH = #lines * lineHeight + padding * 2
    
    -- Position tooltip (offset from cursor)
    local tooltipX = mouseX + 12
    local tooltipY = mouseY + 12
    
    -- Keep within screen bounds
    if tooltipX + tooltipW > 1920 then
        tooltipX = mouseX - tooltipW - 12
    end
    if tooltipY + tooltipH > 1080 then
        tooltipY = mouseY - tooltipH - 12
    end
    
    -- Draw background
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", tooltipX - 2, tooltipY - 2, tooltipW + 4, tooltipH + 4)
    
    -- Draw border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("line", tooltipX - 2, tooltipY - 2, tooltipW + 4, tooltipH + 4)
    
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
    
    love.graphics.setFont(Theme.getFont(Theme.fonts.title))
end

return Tooltips
