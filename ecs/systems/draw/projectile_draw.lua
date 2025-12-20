local Utils = require("ecs.systems.draw.render_utils")

local ProjectileDraw = {}

function ProjectileDraw.draw(ctx, e, body, x, y)
  local drawIt = true
  if ctx.viewLeft then
    local rCull = 18
    if x + rCull < ctx.viewLeft - ctx.cullPad or x - rCull > ctx.viewRight + ctx.cullPad
      or y + rCull < ctx.viewTop - ctx.cullPad or y - rCull > ctx.viewBottom + ctx.cullPad then
      drawIt = false
    end
  end

  if not drawIt then
    return
  end

  local vx, vy = body:getLinearVelocity()
  local speed2 = vx * vx + vy * vy

  local nx, ny = 1, 0
  if speed2 > 0.001 then
    local inv = 1 / math.sqrt(speed2)
    nx, ny = vx * inv, vy * inv
  end

  local len = 8
  love.graphics.setLineWidth(4)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.line(x - nx * len * 0.5, y - ny * len * 0.5, x + nx * len * 0.5, y + ny * len * 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.00, 1.00, 1.00, 0.95)
  love.graphics.line(x - nx * len * 0.5, y - ny * len * 0.5, x + nx * len * 0.5, y + ny * len * 0.5)
  love.graphics.setLineWidth(2)
end

return ProjectileDraw
