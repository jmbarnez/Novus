local ShatterDraw = {}

function ShatterDraw.draw(e, body)
  local x, y = body:getPosition()
  local c = e.shatter

  local t = 0
  if c.duration and c.duration > 0 then
    t = c.t / c.duration
  end

  local a = math.max(0, math.min(1, t))

  love.graphics.push()
  love.graphics.translate(x, y)

  local shards = c.shards or {}
  for s = 1, #shards do
    local sh = shards[s]
    local ca = math.cos(sh.ang)
    local sa = math.sin(sh.ang)
    local hx = ca * (sh.len * 0.5)
    local hy = sa * (sh.len * 0.5)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(0, 0, 0, 1 * a)
    love.graphics.line(sh.x - hx, sh.y - hy, sh.x + hx, sh.y + hy)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.00, 1.00, 1.00, 0.95 * a)
    love.graphics.line(sh.x - hx, sh.y - hy, sh.x + hx, sh.y + hy)
  end

  love.graphics.pop()
  love.graphics.setLineWidth(2)
end

return ShatterDraw
