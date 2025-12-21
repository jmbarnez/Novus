local Utils = require("ecs.systems.draw.render_utils")
local WeaponDraw = require("ecs.systems.draw.weapon_draw")

local ShipDraw = {}

local function drawPlayerShip(ctx, e, shape)
  -- Sleek starter drone palette: deep charcoal + cyan accents
  local r, g, b, a = Utils.applyFlashToColor(e, 0.10, 0.14, 0.18, 1)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", shape:getPoints())

  -- Narrow mid-plate (scaled down)
  local pr, pg, pb, pa = Utils.applyFlashToColor(e, 0.16, 0.22, 0.30, 1)
  love.graphics.setColor(pr, pg, pb, pa)
  love.graphics.polygon("fill",
    8, 0,
    3.5, 3,
    0, 4.2,
    -6, 3,
    -7, 0,
    -6, -3,
    0, -4.2,
    3.5, -3
  )

  -- Spine highlight (scaled down)
  local hr, hg, hb, ha = Utils.applyFlashToColor(e, 0.22, 0.30, 0.40, 1)
  love.graphics.setColor(hr, hg, hb, ha)
  love.graphics.polygon("fill",
    6, 0,
    2.5, 2,
    -2, 2.8,
    -5, 1.8,
    -6, 0,
    -5, -1.8,
    -2, -2.8,
    2.5, -2
  )

  -- Outline
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line", shape:getPoints())

  -- Wing blades (thin cyan, smaller reach)
  local ar, ag, ab, aa = Utils.applyFlashToColor(e, 0.00, 0.95, 1.00, 0.8)
  love.graphics.setColor(ar, ag, ab, aa)
  love.graphics.polygon("fill", 8, 4.2, 1.8, 8.5, -4, 5, 1.8, 3.0)
  love.graphics.polygon("fill", 8, -4.2, 1.8, -8.5, -4, -5, 1.8, -3.0)
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.setLineWidth(0.7)
  love.graphics.polygon("line", 8, 4.2, 1.8, 8.5, -4, 5, 1.8, 3.0)
  love.graphics.polygon("line", 8, -4.2, 1.8, -8.5, -4, -5, 1.8, -3.0)

  -- Motion stripes
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.setLineWidth(0.7)
  love.graphics.line(6, 0, -8, 0)
  love.graphics.line(4, 2, -5, 2)
  love.graphics.line(4, -2, -5, -2)

  -- Cockpit bubble
  local cr, cg, cb, ca = Utils.applyFlashToColor(e, 0.04, 0.16, 0.22, 0.95)
  love.graphics.setColor(cr, cg, cb, ca)
  love.graphics.ellipse("fill", 3.2, 0, 2.6, 1.8)
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.setLineWidth(0.9)
  love.graphics.ellipse("line", 3.2, 0, 2.6, 1.8)
  love.graphics.setColor(0.45, 0.75, 0.9, 0.35)
  love.graphics.ellipse("fill", 4.2, -0.5, 1.2, 0.8)

  -- Rear pods + glow (scaled down)
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.line(-5, 6.5, -11, 4.5)
  love.graphics.line(-5, -6.5, -11, -4.5)

  local er, eg, eb, ea = Utils.applyFlashToColor(e, 0.08, 0.10, 0.14, 1)
  love.graphics.setColor(er, eg, eb, ea)
  love.graphics.circle("fill", -9, 6, 1.8)
  love.graphics.circle("fill", -9, -6, 1.8)
  love.graphics.setColor(0.00, 0.95, 1.00, 0.8)
  love.graphics.circle("fill", -9, 6, 1.0)
  love.graphics.circle("fill", -9, -6, 1.0)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.setLineWidth(0.8)
  love.graphics.circle("line", -9, 6, 1.8)
  love.graphics.circle("line", -9, -6, 1.8)

  -- Nose sensor
  love.graphics.setColor(0.00, 1.00, 1.00, 0.9)
  love.graphics.circle("fill", 12, 0, 1.6)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.circle("line", 12, 0, 1.6)

  -- Vent slits
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", -3.5, 3.8, 1.8, 0.7)
  love.graphics.rectangle("fill", -3.5, -4.6, 1.8, 0.7)
  love.graphics.setColor(0.00, 0.8, 0.9, 0.4)
  love.graphics.rectangle("fill", -3.2, 3.9, 1.2, 0.45)
  love.graphics.rectangle("fill", -3.2, -4.45, 1.2, 0.45)
end

local function drawEnemyShip(e, shape)
  -- Base hull
  local r, g, b, a = Utils.applyFlashToColor(e, 0.18, 0.08, 0.10, 1)
  love.graphics.setColor(r, g, b, a)
  love.graphics.polygon("fill", shape:getPoints())

  -- Hull highlight
  local hr, hg, hb, ha = Utils.applyFlashToColor(e, 0.28, 0.12, 0.14, 1)
  love.graphics.setColor(hr, hg, hb, ha)
  love.graphics.polygon("fill",
    12, 0,
    5, 5,
    -8, 4,
    -10, 0,
    -8, -4,
    5, -5
  )

  -- Outline
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.setLineWidth(1.5)
  love.graphics.polygon("line", shape:getPoints())

  -- Detail lines
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.line(8, 0, -10, 0)
  love.graphics.circle("line", 4, 0, 3.5)

  -- Engine struts
  love.graphics.line(-6, 12, -16, 6)
  love.graphics.line(-6, -12, -16, -6)

  -- Engines
  love.graphics.setColor(0.8, 0.2, 0.1, 0.85)
  love.graphics.circle("fill", -14, 10, 2.5)
  love.graphics.circle("fill", -14, -10, 2.5)
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.circle("line", -14, 10, 2.5)
  love.graphics.circle("line", -14, -10, 2.5)

  -- Cockpit
  love.graphics.setColor(0.6, 0.1, 0.1, 0.7)
  love.graphics.circle("fill", 4, 0, 3)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.circle("line", 4, 0, 3)
end

local function drawLaserBeam(e)
  if not e:has("laser_beam") then
    return
  end

  local beam = e.laser_beam
  local t = beam.t / beam.duration

  -- Outer glow
  love.graphics.setLineWidth(5)
  love.graphics.setColor(0.00, 0.80, 1.00, 0.25 * t)
  love.graphics.line(beam.startX, beam.startY, beam.endX, beam.endY)

  -- Main beam
  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.00, 1.00, 1.00, 0.65 * t)
  love.graphics.line(beam.startX, beam.startY, beam.endX, beam.endY)

  -- Core
  love.graphics.setLineWidth(1.5)
  love.graphics.setColor(1.00, 1.00, 1.00, 0.35 * t)
  love.graphics.line(beam.startX, beam.startY, beam.endX, beam.endY)

  love.graphics.setLineWidth(2)
end

local function drawEngineThrust(e, isPlayerShip)
  local thrust = (e.ship_input and e.ship_input.thrust) or 0
  if thrust <= 0 or e:has("engine_trail") then
    return
  end

  local flicker = 0.8 + 0.35 * love.math.random()
  local len = 9 * thrust * flicker -- Half size

  if isPlayerShip then
    -- Main flame
    love.graphics.setColor(1.0, 0.65, 0.15, 0.95)
    love.graphics.polygon("fill", -11, -3, -11 - len, 0, -11, 3)

    -- Inner flame
    love.graphics.setColor(1.0, 0.85, 0.4, 0.9)
    love.graphics.polygon("fill", -10.5, -2, -10.5 - (len * 0.65), 0, -10.5, 2)

    -- Core
    love.graphics.setColor(1.0, 0.95, 0.7, 0.85)
    love.graphics.polygon("fill", -10, -1, -10 - (len * 0.35), 0, -10, 1)

    -- Side engine flames
    local sideLen = len * 0.5
    love.graphics.setColor(1.0, 0.20, 0.85, 0.8)
    love.graphics.polygon("fill", -9, 4, -9 - sideLen, 5, -9, 6)
    love.graphics.polygon("fill", -9, -4, -9 - sideLen, -5, -9, -6)

    love.graphics.setColor(1.0, 0.6, 0.95, 0.6)
    love.graphics.polygon("fill", -8.5, 4.5, -8.5 - (sideLen * 0.5), 5, -8.5, 5.5)
    love.graphics.polygon("fill", -8.5, -4.5, -8.5 - (sideLen * 0.5), -5, -8.5, -5.5)
  else
    -- Enemy thrust (red-orange)
    love.graphics.setColor(1.0, 0.4, 0.1, 0.9)
    love.graphics.polygon("fill", -22, -5, -22 - len * 2, 0, -22, 5)
    love.graphics.setColor(1.0, 0.7, 0.3, 0.85)
    love.graphics.polygon("fill", -20, -3, -20 - (len * 2 * 0.6), 0, -20, 3)
  end
end

function ShipDraw.draw(ctx, e, body, shape, x, y, angle)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(angle)

  local isPlayerShip = (ctx.playerShip ~= nil and e == ctx.playerShip)

  if isPlayerShip then
    drawPlayerShip(ctx, e, shape)
  else
    drawEnemyShip(e, shape)
  end

  drawLaserBeam(e)
  drawEngineThrust(e, isPlayerShip)

  love.graphics.setLineWidth(2)
  love.graphics.pop()

  if e.auto_cannon then
    if love.mouse.isDown(2) and e.auto_cannon.aimX and e.auto_cannon.aimY then
      WeaponDraw.drawAimIndicator(body, e.auto_cannon)
    end
  end
end

return ShipDraw
