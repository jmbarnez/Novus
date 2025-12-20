local Math = require("util.math")

local clamp = Math.clamp
local cos, sin, pi = math.cos, math.sin, math.pi

local WeaponDraw = {}

function WeaponDraw.drawAimIndicator(sx, sy, aimX, aimY)
  local dx, dy = aimX - sx, aimY - sy
  if (dx * dx + dy * dy) <= 0.0001 then
    return
  end

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 10.0))

  -- Single beam instead of a stacked double to avoid the "two lasers" look.
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.18 * pulse)
  love.graphics.line(sx, sy, aimX, aimY)

  local r = 10
  local len = 7
  local gap = 3

  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.12 * pulse)
  love.graphics.circle("line", aimX, aimY, r)
  love.graphics.line(aimX - (gap + len), aimY, aimX - gap, aimY)
  love.graphics.line(aimX + gap, aimY, aimX + (gap + len), aimY)
  love.graphics.line(aimX, aimY - (gap + len), aimX, aimY - gap)
  love.graphics.line(aimX, aimY + gap, aimX, aimY + (gap + len))

  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.35)
  love.graphics.circle("line", aimX, aimY, r)
  love.graphics.line(aimX - (gap + len), aimY, aimX - gap, aimY)
  love.graphics.line(aimX + gap, aimY, aimX + (gap + len), aimY)
  love.graphics.line(aimX, aimY - (gap + len), aimX, aimY - gap)
  love.graphics.line(aimX, aimY + gap, aimX, aimY + (gap + len))

  love.graphics.setBlendMode(bm, am)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
end

function WeaponDraw.drawWeaponCone(body, weapon)
  -- Check if cone should be visible
  if not weapon.coneVis or weapon.coneVis <= 0 then
    return
  end
  if not weapon.coneHalfAngle or weapon.coneHalfAngle <= 0 or weapon.coneHalfAngle >= pi then
    return
  end

  local x, y = body:getPosition()
  local a = body:getAngle()
  local r = weapon.coneVisLen or 0
  if r <= 0 then
    return
  end

  local halfAngle = weapon.coneHalfAngle

  -- Calculate fade alpha
  local fade = weapon.coneVisFade or 0
  local alpha = 1
  if fade > 0 and weapon.coneVis <= fade then
    alpha = clamp(weapon.coneVis / fade, 0, 1)
  end

  -- Calculate cone boundary points
  local ax1 = x + cos(a - halfAngle) * r
  local ay1 = y + sin(a - halfAngle) * r
  local ax2 = x + cos(a + halfAngle) * r
  local ay2 = y + sin(a + halfAngle) * r

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 8.0))

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.10 * alpha * pulse)
  love.graphics.line(x, y, ax1, ay1)
  love.graphics.line(x, y, ax2, ay2)

  love.graphics.setBlendMode(bm, am)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.18 * alpha)
  love.graphics.line(x, y, ax1, ay1)
  love.graphics.line(x, y, ax2, ay2)

  love.graphics.setColor(1, 1, 1, 1)
end

return WeaponDraw
