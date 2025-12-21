local TargetPanelTopCenter = {}

local Theme = require("game.theme")
local MathUtil = require("util.math")
local DrawHelpers = require("game.hud.draw_helpers")

local safeFrac = DrawHelpers.safeFrac
local drawBar = DrawHelpers.drawBar

function TargetPanelTopCenter.hitTest(ctx, x, y)
  if not ctx or not ctx.world then
    return false
  end

  local targeting = ctx.world:getResource("targeting")
  local target = targeting and targeting.selected or nil
  if not target or not target.inWorld or not target:inWorld() then
    return false
  end

  if not target:has("health") or not target:has("physics_body") then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local tp = hudTheme.targetPanel or {}

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local y0 = layout.topCenterY or margin

  local w = tp.w or 240
  local h = tp.h or 62
  local x0 = math.floor(((ctx.screenW or 0) - w) * 0.5)
  return x >= x0 and x <= (x0 + w) and y >= y0 and y <= (y0 + h)
end

function TargetPanelTopCenter.draw(ctx)
  if not ctx or not ctx.world then
    return
  end

  local targeting = ctx.world:getResource("targeting")
  local target = targeting and targeting.selected or nil
  if not target or not target.inWorld or not target:inWorld() then
    return
  end

  if not target:has("health") or not target:has("physics_body") then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local tp = hudTheme.targetPanel or {}
  local ps = hudTheme.panelStyle or {}

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local y0 = layout.topCenterY or margin

  local w = tp.w or 240
  local h = tp.h or 62
  local x0 = math.floor(((ctx.screenW or 0) - w) * 0.5)

  local pad = tp.pad or 8
  local barH = tp.barH or 8
  local titleYOffset = tp.titleYOffset or -2
  local barYOffset = tp.barYOffset or 6
  local hpTextGap = tp.hpTextGap or 2

  local body = target.physics_body and target.physics_body.body
  local tx, ty = body:getPosition()

  local shipX, shipY = ctx.x or 0, ctx.y or 0
  local dx = tx - shipX
  local dy = ty - shipY
  local dist = math.sqrt(dx * dx + dy * dy)

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

  local title = "TARGET"
  love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
  love.graphics.print(title, x0 + pad + 1, y0 + pad + titleYOffset + 1)
  love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4])
  love.graphics.print(title, x0 + pad, y0 + pad + titleYOffset)

  local info = string.format("%dm", math.floor(dist + 0.5))
  local font = love.graphics.getFont()
  local infoW = font:getWidth(info)
  love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
  love.graphics.print(info, x0 + w - pad - infoW + 1, y0 + pad + titleYOffset + 1)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  love.graphics.print(info, x0 + w - pad - infoW, y0 + pad + titleYOffset)

  local barX = x0 + pad
  local barY = y0 + pad + font:getHeight() + barYOffset
  local barW = w - pad * 2

  local frac = safeFrac(target.health.current, target.health.max)
  local healthColor = tp.healthFill or { 1.00, 0.90, 0.20, 0.90 }
  drawBar(barX, barY, barW, barH, frac, healthColor, colors)

  local hpText = string.format("%d / %d", math.floor(target.health.current or 0), math.floor(target.health.max or 0))
  local hpX = barX
  local hpY = barY + barH + hpTextGap
  love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
  love.graphics.print(hpText, hpX + 1, hpY + 1)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  love.graphics.print(hpText, hpX, hpY)

  local pct = math.floor(frac * 100 + 0.5)
  local pctText = string.format("%d%%", pct)
  local pctW = font:getWidth(pctText)
  local pctX = x0 + w - pad - pctW
  love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
  love.graphics.print(pctText, pctX + 1, hpY + 1)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  love.graphics.print(pctText, pctX, hpY)

  love.graphics.setColor(1, 1, 1, 1)

  if ctx.layout then
    ctx.layout.topCenterY = y0 + h + hudTheme.layout.stackGap
  end
end

return TargetPanelTopCenter
