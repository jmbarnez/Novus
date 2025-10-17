-- UI Hotbar Module - Displays a hotbar with 8 slots at the bottom center of the screen

local Theme = require('src.ui.theme')

local Hotbar = {
    slotCount = 8,
    slots = {}, -- {item, cooldown, ...}
}

function Hotbar.draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local slotSize = 48
    local slotSpacing = 12
    local totalWidth = Hotbar.slotCount * slotSize + (Hotbar.slotCount - 1) * slotSpacing
    local x = (screenW - totalWidth) / 2
    local y = screenH - slotSize - 24 -- 24px above bottom

    for i = 1, Hotbar.slotCount do
        local slotX = x + (i - 1) * (slotSize + slotSpacing)
        local slotY = y
        -- Draw slot background
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], 0.92)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 8, 8)
        -- Draw slot border
        love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 8, 8)
        love.graphics.setLineWidth(1)
        -- Draw slot index (1-8)
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], 0.7)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.printf(tostring(i), slotX, slotY + slotSize - 18, slotSize, "center")
        -- TODO: Draw item icon if slot is filled
    end
    love.graphics.setFont(Theme.getFont(Theme.fonts.title))
end

return Hotbar
