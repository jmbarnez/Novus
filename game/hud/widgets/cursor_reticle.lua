local CursorReticle = {}

local Math = require("util.math")

function CursorReticle.draw(ctx)
  if not ctx or not ctx.hasShip then
    return
  end

  local mx, my = love.mouse.getPosition()

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

  local r, g, b, a
  if inCone then
    r, g, b, a = 0.20, 0.85, 1.00, 0.95
  else
    r, g, b, a = 0.70, 0.70, 0.70, 0.75
  end

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 10.0))

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.setLineWidth(2)
  love.graphics.setColor(r, g, b, 0.18 * a * pulse)

  local len = 7
  local gap = 3
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
