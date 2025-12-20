local CursorReticle = {}

local Math = require("util.math")
local Theme = require("game.theme")

local tUnpack = table.unpack or rawget(_G, "unpack")

function CursorReticle.draw(ctx)
  if not ctx then
    return
  end

  local mx, my = love.mouse.getPosition()

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud

  if ctx.uiOverHud then
    local colors = hudTheme.colors
    local cu = hudTheme.cursorUi or {}
    local poly = cu.poly or { 0, 0, 0, 16, 4, 12, 6, 20, 10, 18, 8, 10, 14, 10 }
    local s = cu.scale or 1.0

    local ow = cu.outlineWidth or 1
    local shA = cu.shadowAlpha or 0.70
    local fillA = cu.fillAlpha or 0.95
    local outlineA = cu.outlineAlpha or 0.30

    local fillCol = cu.fill or { 0.20, 0.85, 1.00, 1.00 }
    local outlineCol = cu.outline or { 0.00, 0.00, 0.00, 1.00 }

    love.graphics.push()
    love.graphics.translate(mx + 1, my + 1)
    love.graphics.scale(s, s)
    love.graphics.setColor(0, 0, 0, shA)
    love.graphics.polygon("fill", tUnpack(poly))
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(mx, my)
    love.graphics.scale(s, s)
    love.graphics.setColor(fillCol[1], fillCol[2], fillCol[3], (fillCol[4] or 1) * fillA)
    love.graphics.polygon("fill", tUnpack(poly))
    love.graphics.setLineWidth(ow)
    love.graphics.setColor(outlineCol[1], outlineCol[2], outlineCol[3], (outlineCol[4] or 1) * outlineA)
    love.graphics.polygon("line", tUnpack(poly))
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  if not ctx.hasShip then
    return
  end

  local inCone = true
  if ctx.weaponConeHalfAngle and ctx.shipAngle and ctx.mouseWorldX and ctx.mouseWorldY and ctx.x and ctx.y then
    local dx = ctx.mouseWorldX - ctx.x
    local dy = ctx.mouseWorldY - ctx.y
    if (dx * dx + dy * dy) > 0.0001 then
      local aimAngle = Math.atan2(dy, dx)
      local delta = Math.normalizeAngle(aimAngle - ctx.shipAngle)
      inCone = math.abs(delta) <= ctx.weaponConeHalfAngle
    end
  end

  local cr = hudTheme.cursorReticle or {}

  local active = cr.active or { 0.20, 0.85, 1.00, 0.95 }
  local inactive = cr.inactive or { 0.70, 0.70, 0.70, 0.75 }

  local col = inCone and active or inactive
  local r, g, b, a = col[1], col[2], col[3], col[4]

  local t = love.timer.getTime()
  local pulseBase = cr.pulseBase or 0.7
  local pulseAmp = cr.pulseAmp or 0.3
  local pulseFreq = cr.pulseFreq or 10.0
  local pulse = pulseBase + pulseAmp * (0.5 + 0.5 * math.sin(t * pulseFreq))

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")
  local lineWidth = cr.lineWidth or 2
  local glowAlpha = cr.glowAlpha or 0.18
  love.graphics.setLineWidth(lineWidth)
  love.graphics.setColor(r, g, b, glowAlpha * a * pulse)

  local len = cr.len or 7
  local gap = cr.gap or 3
  love.graphics.line(mx - (gap + len), my, mx - gap, my)
  love.graphics.line(mx + gap, my, mx + (gap + len), my)
  love.graphics.line(mx, my - (gap + len), mx, my - gap)
  love.graphics.line(mx, my + gap, mx, my + (gap + len))

  love.graphics.setBlendMode(bm, am)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(r, g, b, a)

  love.graphics.line(mx - (gap + len), my, mx - gap, my)
  love.graphics.line(mx + gap, my, mx + (gap + len), my)
  love.graphics.line(mx, my - (gap + len), mx, my - gap)
  love.graphics.line(mx, my + gap, mx, my + (gap + len))

  love.graphics.setColor(1, 1, 1, 1)
end

return CursorReticle
