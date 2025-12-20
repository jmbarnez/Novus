local Utils = require("ecs.systems.draw.render_utils")

local ShipDraw = {}

function ShipDraw.draw(ctx, e, body, shape, x, y, angle)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(angle)

  local isPlayerShip = (ctx.playerShip ~= nil and e == ctx.playerShip)
  if isPlayerShip then
    local r, g, b, a = Utils.applyFlashToColor(e, 0.12, 0.16, 0.22, 1)
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill", shape:getPoints())

    local pr, pg, pb, pa = Utils.applyFlashToColor(e, 0.18, 0.24, 0.32, 1)
    love.graphics.setColor(pr, pg, pb, pa)
    love.graphics.polygon("fill",
      16, 0,
      7, 6,
      0, 10,
      -12, 5,
      -14, 0,
      -12, -5,
      0, -10,
      7, -6
    )

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.polygon("line", shape:getPoints())

    local ar, ag, ab, aa = Utils.applyFlashToColor(e, 0.00, 1.00, 1.00, 0.85)
    love.graphics.setColor(ar, ag, ab, aa)
    love.graphics.polygon("fill",
      12, 6,
      2, 12,
      -8, 6,
      2, 4
    )
    love.graphics.polygon("fill",
      12, -6,
      2, -12,
      -8, -6,
      2, -4
    )

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.polygon("line", 12, 6, 2, 12, -8, 6, 2, 4)
    love.graphics.polygon("line", 12, -6, 2, -12, -8, -6, 2, -4)

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.line(8, 0, -10, 0)
    love.graphics.circle("line", 4, 0, 4)

    love.graphics.line(-6, 12, -16, 6)
    love.graphics.line(-6, -12, -16, -6)
    love.graphics.circle("line", -14, 10, 2)
    love.graphics.circle("line", -14, -10, 2)

    local cr, cg, cb, ca = Utils.applyFlashToColor(e, 0.05, 0.12, 0.16, 0.9)
    love.graphics.setColor(cr, cg, cb, ca)
    love.graphics.circle("fill", 6, 0, 4)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.circle("line", 6, 0, 4)

    love.graphics.setColor(0.00, 1.00, 1.00, 0.95)
    love.graphics.circle("fill", 18, 0, 2.5)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("line", 18, 0, 2.5)

    love.graphics.setColor(1.00, 0.20, 0.85, 0.9)
    love.graphics.circle("fill", -14, 10, 2)
    love.graphics.circle("fill", -14, -10, 2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("line", -14, 10, 2)
    love.graphics.circle("line", -14, -10, 2)
  else
    Utils.applyFlashColor(e)
    love.graphics.polygon("line", shape:getPoints())

    love.graphics.line(8, 0, -10, 0)
    love.graphics.circle("line", 4, 0, 4)

    love.graphics.line(-6, 12, -16, 6)
    love.graphics.line(-6, -12, -16, -6)
    love.graphics.circle("line", -14, 10, 2)
    love.graphics.circle("line", -14, -10, 2)
  end

  if e:has("laser_beam") then
    local beam = e.laser_beam
    local t = beam.t / beam.duration
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.00, 1.00, 1.00, 0.65 * t)
    love.graphics.line(beam.startX, beam.startY, beam.endX, beam.endY)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1.00, 1.00, 1.00, 0.18 * t)
    love.graphics.line(beam.startX, beam.startY, beam.endX, beam.endY)
    love.graphics.setLineWidth(2)
  end

  local thrust = (e.ship_input and e.ship_input.thrust) or 0
  if thrust > 0 and not e:has("engine_trail") then
    local flicker = 0.8 + 0.35 * love.math.random()
    local len = 16 * thrust * flicker

    love.graphics.setColor(1.0, 0.75, 0.25, 0.9)
    love.graphics.polygon("fill", -22, -5, -22 - len, 0, -22, 5)
    love.graphics.setColor(1.0, 0.9, 0.6, 0.9)
    love.graphics.polygon("fill", -20, -3, -20 - (len * 0.6), 0, -20, 3)

    Utils.applyFlashColor(e)
  end

  love.graphics.pop()
end

return ShipDraw
