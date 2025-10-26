local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local BatchRenderer = require('src.ui.batch_renderer')
local HoverSound = require('src.ui.hover_sound')

local ConstructionButton = {
    id = "construction_btn",
    _hovered = false,
    _btnRectUI = nil, -- stores button position/size in UI space for hit-testing
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
    BatchRenderer.queuePolygon(hex_points, color[1], color[2], color[3], (color[4] or 1) * alpha)
    -- Wrench: simple diagonal handle
    -- This is tricky with BatchRenderer, so we'll approximate with a thin rectangle
    -- Wrench head (crescent shape)
    -- This is also tricky, so we'll skip it for now
end

function ConstructionButton.update(dt)
    -- Hover detection (convert mouse to UI coordinates)
    local mx, my = love.mouse.getPosition()
    local uiMx, uiMy = Scaling.toUI(mx, my)
    
    local basePadding = Theme.spacing.padding * 2
    local baseIconSize = 44
    local baseBtnW = baseIconSize + basePadding * 2
    local baseBtnH = baseIconSize + basePadding * 2
    local baseMargin = basePadding * 1.2

    -- Use actual screen dimensions for positioning, consistent with draw function
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local uiScreenW, uiScreenH = Scaling.toUI(screenW, screenH)

    local uiX = uiScreenW - baseBtnW - baseMargin
    local uiY = uiScreenH - baseBtnH - baseMargin
    
    ConstructionButton._hovered = uiMx >= uiX and uiMx <= uiX + baseBtnW and uiMy >= uiY and uiMy <= uiY + baseBtnH
    ConstructionButton._btnRectUI = {x = uiX, y = uiY, w = baseBtnW, h = baseBtnH}
end

function ConstructionButton.draw(viewportWidth, viewportHeight)
    viewportWidth = viewportWidth or love.graphics.getWidth()
    viewportHeight = viewportHeight or love.graphics.getHeight()

    local basePadding = Theme.spacing.padding * 2
    local baseIconSize = 44
    local baseBtnW = baseIconSize + basePadding * 2
    local baseBtnH = baseIconSize + basePadding * 2
    local baseMargin = basePadding * 1.2

    -- Convert screen dimensions to UI space for positioning
    local uiScreenW, uiScreenH = Scaling.toUI(viewportWidth, viewportHeight)
    local uiX = uiScreenW - baseBtnW - baseMargin
    local uiY = uiScreenH - baseBtnH - baseMargin

    -- Draw plasma/energy theme button
    HoverSound.update("construction_button", ConstructionButton._hovered, {
        bounds = {x = uiX, y = uiY, w = baseBtnW, h = baseBtnH},
        space = "ui",
    })

    local color = ConstructionButton._hovered and Theme.colors.buttonHover or Theme.colors.bgDark
    BatchRenderer.queueRect(uiX, uiY, baseBtnW, baseBtnH, color[1], color[2], color[3], 1)
    BatchRenderer.queueRectLine(uiX, uiY, baseBtnW, baseBtnH, Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], 1, 2)
    -- Draw hex-wrench icon
    drawHexWrench(uiX + baseBtnW / 2, uiY + baseBtnH / 2 + 2, baseIconSize, Theme.colors.textPrimary, 1)
    -- Label
    local font = Theme.getFontBold(Theme.fonts.small)
    BatchRenderer.queueText("BUILD", uiX, uiY + baseBtnH - 14, font, Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], 1, "center", baseBtnW)
end

function ConstructionButton.checkPressed(mx, my, button)
    local r = ConstructionButton._btnRectUI
    if not r then return false end
    local uiMx, uiMy = Scaling.toUI(mx, my)
    if button == 1 and uiMx >= r.x and uiMx <= r.x + r.w and uiMy >= r.y and uiMy <= r.y + r.h then
        return true
    end
    return false
end

return ConstructionButton
