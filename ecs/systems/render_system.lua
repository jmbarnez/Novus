local Concord = require("lib.concord")
local ItemIcons = require("game.item_icons")

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function lerpAngle(a, b, t)
  local d = (b - a + math.pi) % (math.pi * 2) - math.pi
  return a + d * t
end

local function buildExpandedOutlineCoords(baseCoords, pad)
  local coords = {}
  for i = 1, #baseCoords, 2 do
    local x = baseCoords[i]
    local y = baseCoords[i + 1]
    local len = math.sqrt(x * x + y * y)
    if len > 0.0001 then
      local s = (len + pad) / len
      coords[i] = x * s
      coords[i + 1] = y * s
    else
      coords[i] = x
      coords[i + 1] = y
    end
  end
  return coords
end

local function getAsteroidTargetOutlineCoords(e, shape, pad)
  local a = e.asteroid
  if not a then
    return nil
  end

  local baseCoords
  if a.renderCoords then
    baseCoords = a.renderCoords
  else
    if not a._physicsRenderCoords then
      a._physicsRenderCoords = { shape:getPoints() }
    end
    baseCoords = a._physicsRenderCoords
  end

  if a._targetOutlineCoords and a._targetOutlinePad == pad and a._targetOutlineBase == baseCoords then
    return a._targetOutlineCoords
  end

  a._targetOutlineCoords = buildExpandedOutlineCoords(baseCoords, pad)
  a._targetOutlinePad = pad
  a._targetOutlineBase = baseCoords
  return a._targetOutlineCoords
end

local RenderSystem = Concord.system({
  renderables = { "physics_body", "renderable" },
})

local function applyFlashToColor(e, r, g, b, a)
  if e:has("hit_flash") then
    local t = e.hit_flash.t / e.hit_flash.duration
    r = r + (1 - r) * t
    g = g + (1 - g) * t
    b = b + (1 - b) * t
  end

  return r, g, b, a
end

local function applyFlashColor(e)
  local r, g, b, a = e.renderable.color[1], e.renderable.color[2], e.renderable.color[3], e.renderable.color[4]

  if e:has("hit_flash") then
    local t = e.hit_flash.t / e.hit_flash.duration
    r = r + (1 - r) * t
    g = g + (1 - g) * t
    b = b + (1 - b) * t
  end

  love.graphics.setColor(r, g, b, a)
end

function RenderSystem:init(world)
  self.world = world
end

function RenderSystem:drawWorld()
  love.graphics.setLineWidth(2)

  local playerShip = nil
  if self.world then
    local player = self.world:getResource("player")
    if player and player:has("pilot") and player.pilot.ship then
      playerShip = player.pilot.ship
    end
  end

  local mapUi = self.world and self.world.getResource and self.world:getResource("map_ui")
  if mapUi and mapUi.waypointX and mapUi.waypointY then
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

  local view = self.world and self.world.getResource and self.world:getResource("camera_view")
  local alpha = self.world and self.world.getResource and self.world:getResource("render_alpha")
  local targeting = self.world and self.world.getResource and self.world:getResource("targeting")
  local hovered = targeting and targeting.hovered or nil
  local selected = targeting and targeting.selected or nil
  if alpha == nil then
    alpha = 1
  end
  if alpha < 0 then
    alpha = 0
  elseif alpha > 1 then
    alpha = 1
  end

  local viewLeft, viewTop, viewRight, viewBottom
  if view then
    viewLeft = view.camX
    viewTop = view.camY
    viewRight = view.camX + view.viewW
    viewBottom = view.camY + view.viewH
  end

  local cullPad = 140

  for i = 1, self.renderables.size do
    local e = self.renderables[i]

    local pb = e.physics_body
    local body = pb.body
    local shape = pb.shape

    local x, y = body:getPosition()
    local angle = body:getAngle()
    if pb.prevX ~= nil and pb.prevY ~= nil and pb.prevA ~= nil and alpha ~= 1 then
      x = lerp(pb.prevX, x, alpha)
      y = lerp(pb.prevY, y, alpha)
      angle = lerpAngle(pb.prevA, angle, alpha)
    end

    if e.renderable.kind == "ship" then
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.rotate(angle)

      local isPlayerShip = (playerShip ~= nil and e == playerShip)
      if isPlayerShip then
        local r, g, b, a = applyFlashToColor(e, 0.12, 0.16, 0.22, 1)
        love.graphics.setColor(r, g, b, a)
        love.graphics.polygon("fill", shape:getPoints())

        local pr, pg, pb, pa = applyFlashToColor(e, 0.18, 0.24, 0.32, 1)
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

        local ar, ag, ab, aa = applyFlashToColor(e, 0.00, 1.00, 1.00, 0.85)
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

        local cr, cg, cb, ca = applyFlashToColor(e, 0.05, 0.12, 0.16, 0.9)
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
        applyFlashColor(e)
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

        applyFlashColor(e)
      end

      love.graphics.pop()
    elseif e.renderable.kind == "asteroid" then
      local drawIt = true
      if viewLeft then
        local rCull = (e.asteroid and e.asteroid.radius) or 30
        if x + rCull < viewLeft - cullPad or x - rCull > viewRight + cullPad or y + rCull < viewTop - cullPad or y - rCull > viewBottom + cullPad then
          drawIt = false
        end
      end

      if drawIt then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(angle)

        if e == selected or e == hovered then
          love.graphics.push("all")
          if e == selected then
            love.graphics.setColor(1.00, 0.35, 0.95, 0.55)
            love.graphics.setLineWidth(3)
          else
            love.graphics.setColor(0.00, 1.00, 1.00, 0.40)
            love.graphics.setLineWidth(2)
          end

          local outline = getAsteroidTargetOutlineCoords(e, shape, 10)
          if outline then
            love.graphics.polygon("line", outline)
          else
            local r = (e.asteroid and e.asteroid.radius) or 30
            love.graphics.circle("line", 0, 0, r + 10)
          end
          love.graphics.pop()
        end

        applyFlashColor(e)
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
    elseif e.renderable.kind == "projectile" then
      local drawIt = true
      if viewLeft then
        local rCull = 18
        if x + rCull < viewLeft - cullPad or x - rCull > viewRight + cullPad or y + rCull < viewTop - cullPad or y - rCull > viewBottom + cullPad then
          drawIt = false
        end
      end

      if drawIt then
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
    elseif e.renderable.kind == "pickup" then
      local x, y = body:getPosition()

      if e:has("pickup") and e.pickup and e.pickup.id == "stone" then
        local r0, g0, b0, a0 = e.renderable.color[1], e.renderable.color[2], e.renderable.color[3], e.renderable.color[4]
        local r, g, b, a = applyFlashToColor(e, r0, g0, b0, a0)
        ItemIcons.drawCentered("stone", x, y, 14, { color = { r, g, b, a } })
      else
        applyFlashColor(e)
        love.graphics.circle("fill", x, y, 6)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.circle("line", x, y, 6)
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.circle("line", x - 1, y - 1, 4)
      end
    elseif e.renderable.kind == "shatter" and e:has("shatter") then
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

        love.graphics.setLineWidth(3)
        love.graphics.setColor(0, 0, 0, 1 * a)
        love.graphics.line(sh.x - hx, sh.y - hy, sh.x + hx, sh.y + hy)

        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.00, 1.00, 1.00, 0.9 * a)
        love.graphics.line(sh.x - hx, sh.y - hy, sh.x + hx, sh.y + hy)
      end

      love.graphics.pop()
      love.graphics.setLineWidth(2)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function RenderSystem:draw()
  return self:drawWorld()
end

return RenderSystem
