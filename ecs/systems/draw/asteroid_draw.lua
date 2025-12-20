local Utils = require("ecs.systems.draw.render_utils")

local AsteroidDraw = {}

function AsteroidDraw.draw(ctx, e, body, shape, x, y, angle)
  local drawIt = true
  if ctx.viewLeft then
    local rCull = (e.asteroid and e.asteroid.radius) or 30
    if x + rCull < ctx.viewLeft - ctx.cullPad or x - rCull > ctx.viewRight + ctx.cullPad
      or y + rCull < ctx.viewTop - ctx.cullPad or y - rCull > ctx.viewBottom + ctx.cullPad then
      drawIt = false
    end
  end

  if not drawIt then
    return
  end

  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(angle)

  if e == ctx.selected or e == ctx.hovered then
    love.graphics.push("all")
    if e == ctx.selected then
      love.graphics.setColor(1.00, 0.35, 0.95, 0.55)
      love.graphics.setLineWidth(10)
    else
      love.graphics.setColor(0.00, 1.00, 1.00, 0.40)
      love.graphics.setLineWidth(8)
    end

    local outline = Utils.getAsteroidTargetOutlineCoords(e, shape, 0)
    if outline then
      love.graphics.polygon("line", outline)
    else
      local r = (e.asteroid and e.asteroid.radius) or 30
      love.graphics.circle("line", 0, 0, r)
    end
    love.graphics.pop()
  end

  Utils.applyFlashColor(e)
  if e.asteroid and e.asteroid.renderCoords then
    love.graphics.polygon("fill", e.asteroid.renderCoords)
  else
    love.graphics.polygon("fill", shape:getPoints())
  end

  love.graphics.push("all")
  love.graphics.setLineJoin("bevel")
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.setLineWidth(2.25)
  if e.asteroid and e.asteroid.renderCoords then
    love.graphics.polygon("line", e.asteroid.renderCoords)
  else
    love.graphics.polygon("line", shape:getPoints())
  end
  love.graphics.pop()

  love.graphics.setLineWidth(2)
  love.graphics.setColor(1, 1, 1, 1)

  if e:has("health") and e:has("asteroid") and e.health.max and e.health.max > 0 and e.health.current < e.health.max then
    local ratio = e.health.current / e.health.max
    if ratio < 0 then
      ratio = 0
    elseif ratio > 1 then
      ratio = 1
    end

    -- Draw unrotated so the bar stays visually "above" the asteroid regardless of spin.
    local r = e.asteroid.radius or 30
    local barW = math.max(26, r * 1.6)
    local barH = 6
    local barX = -barW / 2
    local barY = -(r + 18)

    love.graphics.push()
    love.graphics.rotate(-angle)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", barX, barY, barW, barH)
    love.graphics.setColor(1.00, 0.90, 0.20, 0.95)
    love.graphics.rectangle("fill", barX + 1, barY + 1, (barW - 2) * ratio, barH - 2)
    love.graphics.pop()
  end

  love.graphics.pop()
end

return AsteroidDraw
