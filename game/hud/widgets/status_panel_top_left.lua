local StatusPanelTopLeft = {}

local Theme = require("game.theme")
local MathUtil = require("util.math")

local function safeFrac(num, den)
  if not den or den <= 0 then
    return 0
  end
  return MathUtil.clamp((num or 0) / den, 0, 1)
end

local function drawBar(x, y, w, h, frac, fillColor, colors)
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

local function drawCircleBar(cx, cy, radius, thickness, frac, fillColor, bgColor)
  local segments = 32
  local startAngle = -math.pi / 2
  local endAngle = startAngle + math.pi * 2 * MathUtil.clamp(frac or 0, 0, 1)

  love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
  love.graphics.setLineWidth(thickness)
  love.graphics.circle("line", cx, cy, radius, segments)

  if frac > 0 then
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4])
    love.graphics.setLineWidth(thickness)
    love.graphics.arc("line", "open", cx, cy, radius, startAngle, endAngle, segments)
  end

  love.graphics.setLineWidth(1)
end

function StatusPanelTopLeft.hitTest(ctx, x, y)
  if not ctx then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local sp = hudTheme.statusPanel or {}

  local margin = (ctx.layout and ctx.layout.margin) or hudTheme.layout.margin
  local x0 = margin
  local y0 = (ctx.layout and ctx.layout.topLeftY) or margin

  local circleRadius = sp.circleRadius or 18
  local barW = sp.barW or 80
  local panelPad = sp.panelPad or 6

  local w = circleRadius * 2 + panelPad * 3 + barW
  local h = circleRadius * 2 + panelPad * 2

  return x >= x0 and x <= (x0 + w) and y >= y0 and y <= (y0 + h)
end

function StatusPanelTopLeft.draw(ctx)
  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local sp = hudTheme.statusPanel or {}
  local ps = hudTheme.panelStyle or {}

  local margin = (ctx.layout and ctx.layout.margin) or hudTheme.layout.margin
  local x0 = margin
  local y0 = (ctx.layout and ctx.layout.topLeftY) or margin

  local circleRadius = sp.circleRadius or 18
  local circleThickness = sp.circleThickness or 3
  local barW = sp.barW or 80
  local barH = sp.barH or 6
  local barGap = sp.barGap or 4
  local panelPad = sp.panelPad or 6

  local w = circleRadius * 2 + panelPad * 3 + barW
  local h = circleRadius * 2 + panelPad * 2

  -- panel
  local r = ps.radius or 0
  local shadowOffset = ps.shadowOffset or 0
  local shadowAlpha = ps.shadowAlpha or 0
  if shadowOffset ~= 0 and shadowAlpha > 0 then
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", x0 + shadowOffset, y0 + shadowOffset, w, h, r, r)
  end

  love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4])
  love.graphics.rectangle("fill", x0, y0, w, h, r, r)

  love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], colors.panelBorder[4])
  love.graphics.setLineWidth(ps.borderWidth or 1)
  love.graphics.rectangle("line", x0, y0, w, h, r, r)
  love.graphics.setLineWidth(1)

  local level = ctx.playerLevel or 1
  local xp = ctx.playerXp or 0
  local xpToNext = ctx.playerXpToNext or 100
  local xpFrac = safeFrac(xp, xpToNext)

  -- left: circular XP bar with level text inside
  local circleCX = x0 + panelPad + circleRadius
  local circleCY = y0 + panelPad + circleRadius

  local xpFillColor = sp.xpFill or { 0.9, 0.75, 0.2, 0.9 }
  local xpBgColor = sp.xpBg or { 0.3, 0.3, 0.3, 0.5 }
  drawCircleBar(circleCX, circleCY, circleRadius - circleThickness / 2, circleThickness, xpFrac, xpFillColor, xpBgColor)

  local font = love.graphics.getFont()
  local levelText = tostring(level)
  local tw = font:getWidth(levelText)
  local th = font:getHeight()
  love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
  love.graphics.print(levelText, circleCX - tw / 2 + 1, circleCY - th / 2 + 1)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  love.graphics.print(levelText, circleCX - tw / 2, circleCY - th / 2)

  -- right: Hull + Shield bars
  local rightX = x0 + panelPad * 2 + circleRadius * 2
  local barsHeight = barH * 2 + barGap
  local topY = y0 + (h - barsHeight) / 2

  local hullColor = sp.hullFill or { 0.9, 0.4, 0.2, 0.85 }
  local shieldColor = sp.shieldFill or { 0.2, 0.8, 0.9, 0.85 }

  drawBar(rightX, topY, barW, barH, safeFrac(ctx.hullCur, ctx.hullMax), hullColor, colors)
  drawBar(rightX, topY + barH + barGap, barW, barH, safeFrac(ctx.shieldCur, ctx.shieldMax), shieldColor, colors)

  love.graphics.setColor(1, 1, 1, 1)

  if ctx.layout then
    ctx.layout.topLeftY = y0 + h + hudTheme.layout.stackGap
  end
end

return StatusPanelTopLeft
