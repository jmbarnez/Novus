local Theme = require("game.theme")
local MathUtil = require("util.math")

local function formatDistance(d)
  if d >= 10000 then
    return string.format("%.0fk", d / 1000)
  end
  if d >= 1000 then
    return string.format("%.1fk", d / 1000)
  end
  return string.format("%.0f", d)
end

local WaypointIndicator = {}

local function edgeIntersect(cx, cy, ux, uy, minX, minY, maxX, maxY)
  local bestT = nil

  if ux > 0 then
    local t = (maxX - cx) / ux
    local y = cy + uy * t
    if y >= minY and y <= maxY and t > 0 and (not bestT or t < bestT) then
      bestT = t
    end
  elseif ux < 0 then
    local t = (minX - cx) / ux
    local y = cy + uy * t
    if y >= minY and y <= maxY and t > 0 and (not bestT or t < bestT) then
      bestT = t
    end
  end

  if uy > 0 then
    local t = (maxY - cy) / uy
    local x = cx + ux * t
    if x >= minX and x <= maxX and t > 0 and (not bestT or t < bestT) then
      bestT = t
    end
  elseif uy < 0 then
    local t = (minY - cy) / uy
    local x = cx + ux * t
    if x >= minX and x <= maxX and t > 0 and (not bestT or t < bestT) then
      bestT = t
    end
  end

  if not bestT then
    return cx, cy
  end

  return cx + ux * bestT, cy + uy * bestT
end

function WaypointIndicator.draw(ctx)
  if not ctx or not ctx.hasShip or not ctx.world then
    return
  end

  local mapUi = ctx.world:getResource("map_ui")
  if not mapUi or mapUi.open or not mapUi.waypointX or not mapUi.waypointY then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local colors = theme.hud.colors

  local dx = mapUi.waypointX - (ctx.x or 0)
  local dy = mapUi.waypointY - (ctx.y or 0)

  local ux, uy, dist = MathUtil.normalize(dx, dy)
  if dist <= 0.001 or not ux or not uy then
    return
  end

  local angle = MathUtil.atan2(dy, dx)

  local screenW = ctx.screenW or 0
  local screenH = ctx.screenH or 0
  local cx = screenW * 0.5
  local cy = screenH * 0.5

  local margin = ((theme.hud and theme.hud.layout and theme.hud.layout.margin) or 16) + 42

  local minX = margin
  local minY = margin
  local maxX = screenW - margin
  local maxY = screenH - margin

  local px, py = edgeIntersect(cx, cy, ux, uy, minX, minY, maxX, maxY)

  love.graphics.push()
  love.graphics.translate(px, py)
  love.graphics.rotate(angle)

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.polygon("fill", 0, 0, -16, 9, -11, 0, -16, -9)

  love.graphics.setColor(1.0, 0.35, 0.95, 0.90)
  love.graphics.polygon("fill", 0, 0, -15, 8, -10, 0, -15, -8)

  love.graphics.pop()

  local label = "WP " .. formatDistance(dist)

  local font = love.graphics.getFont()
  local tw = font:getWidth(label)
  local th = font:getHeight()

  local lx = MathUtil.clamp(px - tw * 0.5, 6, (screenW - tw) - 6)
  local ly = MathUtil.clamp(py + 12, 6, (screenH - th) - 6)

  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.print(label, lx + 1, ly + 1)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.90)
  love.graphics.print(label, lx, ly)

  love.graphics.setColor(1, 1, 1, 1)
end

return WaypointIndicator
