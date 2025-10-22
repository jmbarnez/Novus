---@diagnostic disable: undefined-global
-- UI Tooltips Module - Handles tooltip rendering with theme support
-- Displays item information on hover

local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local Tooltips = {}

-- Draw an item tooltip
function Tooltips.drawItemTooltip(itemId, itemDef, count, mouseX, mouseY)
    if not itemDef then return end
    local module = itemDef.module
    local isTurret = module and module.displayName and (module.DPS or module.COOLDOWN or module.RANGE)
    -- Build tooltip lines
    local lines = {}
    if isTurret then
        table.insert(lines, module.displayName)
        
        -- Calculate realistic stats
        if module.CONTINUOUS then
            -- For continuous weapons (lasers), show actual DPS per second
            -- DPS value is damage applied per frame, need to convert to damage per second
            -- Average frame rate is 60 FPS, but we show realistic effective DPS
            local effectiveDPS = module.DPS or 0
            table.insert(lines, string.format("Damage Output: %.0f/sec", effectiveDPS))
            
            if module.HEAT_RATE and module.MAX_HEAT then
                -- Calculate max firing duration before overheat
                local maxFireTime = module.MAX_HEAT / (module.HEAT_RATE or 1.0)
                table.insert(lines, string.format("Max Fire Duration: %.1fs", maxFireTime))
            end
            if module.COOL_RATE then
                table.insert(lines, string.format("Cool Rate: %.1f/sec", module.COOL_RATE))
            end
        else
            -- For projectile weapons, show damage per shot and effective DPS
            if module.DPS then
                local damagePerShot = module.DPS
                table.insert(lines, string.format("Damage per Shot: %.0f", damagePerShot))
            end
            if module.COOLDOWN then
                table.insert(lines, string.format("Fire Rate: %.2fs cooldown", module.COOLDOWN))
                if module.DPS then
                    local effectiveDPS = module.DPS / module.COOLDOWN
                    table.insert(lines, string.format("Effective DPS: %.1f", effectiveDPS))
                end
            end
        end
        
        if module.RANGE then 
            table.insert(lines, string.format("Range: %d units", module.RANGE)) 
        end
        table.insert(lines, "")
    else
        table.insert(lines, itemDef.name)
    end
    table.insert(lines, "Count: " .. count)
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
    
    -- Position tooltip to the right of cursor with proper offset
        local cursorOffset = 16 -- Distance from cursor in UI units
        local tooltipX = mouseX + cursorOffset
        local tooltipY = mouseY - 8 -- Slightly above cursor center
    
    -- Keep within screen bounds
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- If tooltip would go off right edge, position to the left of cursor
    if tooltipX + tooltipW > screenW then
            tooltipX = mouseX - tooltipW - cursorOffset
    end
    
    -- If tooltip would go off bottom edge, position above cursor
    if tooltipY + tooltipH > screenH then
            tooltipY = mouseY - tooltipH - 8
    end
    
    -- If tooltip would go off top edge, position below cursor
    if tooltipY < 0 then
            tooltipY = mouseY + 8
    end
    
    -- Draw background
    love.graphics.setColor(Theme.colors.bgMedium)
    love.graphics.rectangle("fill", tooltipX - Scaling.scaleX(2), tooltipY - Scaling.scaleY(2), tooltipW + Scaling.scaleX(4), tooltipH + Scaling.scaleY(4))
    
    -- Draw thick plasma-style border
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX - Scaling.scaleX(2), tooltipY - Scaling.scaleY(2), tooltipW + Scaling.scaleX(4), tooltipH + Scaling.scaleY(4))
    love.graphics.setLineWidth(1)
    
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
