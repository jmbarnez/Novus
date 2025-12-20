local MapUiDraw = {}

function MapUiDraw.draw(mapUi)
  if not mapUi or not mapUi.waypointX or not mapUi.waypointY then
    return
  end

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * math.sin(t * 3.2)
  local x, y = mapUi.waypointX, mapUi.waypointY

  love.graphics.setColor(1.0, 0.35, 0.95, 0.22 * pulse)
  love.graphics.circle("line", x, y, 34)
  love.graphics.circle("line", x, y, 22)

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.setLineWidth(4)
  love.graphics.line(x - 12, y, x + 12, y)
  love.graphics.line(x, y - 12, x, y + 12)

  love.graphics.setColor(1.0, 0.35, 0.95, 0.95)
  love.graphics.setLineWidth(2)
  love.graphics.line(x - 12, y, x + 12, y)
  love.graphics.line(x, y - 12, x, y + 12)

  love.graphics.setLineWidth(2)
  love.graphics.setColor(1, 1, 1, 1)
end

return MapUiDraw
