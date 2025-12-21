local M = {}

local MathUtil = require("util.math")

--- Calculate a safe fraction, avoiding division by zero
---@param num number Numerator
---@param den number Denominator
---@return number Clamped fraction between 0 and 1
function M.safeFrac(num, den)
    if not den or den <= 0 then
        return 0
    end
    return MathUtil.clamp((num or 0) / den, 0, 1)
end

--- Draw a horizontal progress bar
---@param x number X position
---@param y number Y position
---@param w number Width
---@param h number Height
---@param frac number Fill fraction (0-1)
---@param fillColor table RGBA color for fill
---@param colors table Theme colors with barBg and barBorder
function M.drawBar(x, y, w, h, frac, fillColor, colors)
    local f = MathUtil.clamp(frac or 0, 0, 1)

    local bg = colors.barBg
    love.graphics.setColor(bg[1], bg[2], bg[3], bg[4])
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
    love.graphics.rectangle("fill", x, y, w * f, h)

    local bb = colors.barBorder
    love.graphics.setColor(bb[1], bb[2], bb[3], bb[4])
    love.graphics.rectangle("line", x, y, w, h)
end

return M
