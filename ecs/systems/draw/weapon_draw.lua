local Math = require("util.math")

local clamp = Math.clamp
local cos, sin, pi = math.cos, math.sin, math.pi

local WeaponDraw = {}

function WeaponDraw.drawAimIndicator(body, weapon)
  local sx, sy = body:getPosition()
  local shipAngle = body:getAngle()

  -- Start from the nose of the ship (offset by 12)
  local noseOffset = 12
  local startX = sx + cos(shipAngle) * noseOffset
  local startY = sy + sin(shipAngle) * noseOffset

  -- Calculate target vector relative to nose
  local dx = weapon.aimX - startX
  local dy = weapon.aimY - startY

  local finalAngle
  if weapon.visualAimAngle then
    finalAngle = weapon.visualAimAngle
  else
    -- Calculate aim angle from nose
    local aimAngle = Math.atan2(dy, dx)

    -- Calculate difference relative to ship facing
    local diff = Math.angleDiff(aimAngle, shipAngle)

    -- Clamp difference to cone half angle
    local clampedDiff = clamp(diff, -weapon.coneHalfAngle, weapon.coneHalfAngle)

    -- Calculate final aim angle
    finalAngle = shipAngle + clampedDiff
  end

  -- Calculate distance to cursor, clamped to max range
  local cursorDist = math.sqrt(dx * dx + dy * dy)
  local maxRange = weapon.range or 1200
  local finalDist = clamp(cursorDist, 0, maxRange)

  local tx = startX + cos(finalAngle) * finalDist
  local ty = startY + sin(finalAngle) * finalDist

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")

  local t = love.timer.getTime()
  local pulse = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(t * 10.0))

  -- Single beam to show exactly where the projectile will travel.
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.45 * pulse)
  love.graphics.line(startX, startY, tx, ty)

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
end

return WeaponDraw
