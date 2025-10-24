local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')

local ConstructionButton = {
    id = "construction_btn",
    _hovered = false,
    _btnRect = nil, -- stores button position/size for hit-testing
}

-- Draw a hex-nut with a wrench overlay (plasma-style, fits theme)
local function drawHexWrench(cx, cy, size, color, alpha)
    color = color or Theme.colors.textPrimary
    alpha = alpha or 1
    -- Hex nut
    local hex_radius = size * 0.32
    local hex_points = {}
    for i=0,5 do
        local ang = math.rad(i*60)
        table.insert(hex_points, cx + math.cos(ang)*hex_radius)
        table.insert(hex_points, cy + math.sin(ang)*hex_radius)
    end
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    love.graphics.setLineWidth(3.2)
    love.graphics.polygon('line', hex_points)
    -- Wrench: simple diagonal handle
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(math.rad(-34))
    love.graphics.setLineWidth(5.6)
    love.graphics.line(-size*0.18, -size*0.20, size*0.18, size*0.20)
    -- Wrench head (crescent shape)
    love.graphics.setLineWidth(3.2)
    love.graphics.arc('line', 0, -size*0.20, size*0.07, math.rad(-115), math.rad(35), 12)
    love.graphics.pop()
    love.graphics.setLineWidth(1)
end

function ConstructionButton.draw(viewportWidth, viewportHeight)
    viewportWidth = viewportWidth or love.graphics.getWidth()
    viewportHeight = viewportHeight or love.graphics.getHeight()
    local padding = Scaling.scaleSize(Theme.spacing.padding)*2
    local iconSize = Scaling.scaleSize(44)
    local btnW, btnH = iconSize + padding*2, iconSize + padding*2
    local x = viewportWidth - btnW - padding*1.2
    local y = viewportHeight - btnH - padding*1.2
    -- Hover detection (screen-space)
    local mx, my = love.mouse.getPosition()
    ConstructionButton._hovered = mx >= x and mx <= x + btnW and my >= y and my <= y + btnH
    ConstructionButton._btnRect = {x = x, y = y, w = btnW, h = btnH}
    -- Draw plasma/energy theme button
    Theme.drawButton(x, y, btnW, btnH, '', ConstructionButton._hovered, Theme.colors.bgDark, Theme.colors.buttonHover)
    -- Draw hex-wrench icon
    drawHexWrench(x + btnW/2, y + btnH/2 + 2, iconSize, Theme.colors.textPrimary, 1)
    -- Label
    love.graphics.setFont(Theme.getFontBold(Theme.fonts.small))
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.printf("BUILD", x, y + btnH - Scaling.scaleY(14), btnW, "center")
end

function ConstructionButton.checkPressed(mx, my, button)
    local r = ConstructionButton._btnRect
    if r and button == 1 and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
        return true
    end
    return false
end

return ConstructionButton
