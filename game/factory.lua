local factory = {}

local unpack = table.unpack or _G.unpack
local MathUtil = require("util.math")
local Inventory = require("game.inventory")

local function pickAsteroidColor(rng)
  local palette = {
    { 0.58, 0.56, 0.54 },
    { 0.54, 0.55, 0.60 },
    { 0.60, 0.52, 0.46 },
    { 0.46, 0.50, 0.44 },
    { 0.62, 0.60, 0.50 },
    { 0.50, 0.48, 0.56 },
  }

  local base = palette[rng:random(1, #palette)]
  local v = 0.88 + 0.22 * rng:random()
  local tint = (rng:random() - 0.5) * 0.06

  local r = base[1] * v + tint
  local g = base[2] * v
  local b = base[3] * v - tint

  r = MathUtil.clamp(r, 0, 1)
  g = MathUtil.clamp(g, 0, 1)
  b = MathUtil.clamp(b, 0, 1)

  return { r, g, b, 1.0 }
end

local function cross(o, a, b)
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end
local function convexHull(points)
  table.sort(points, function(p, q)
    if p.x == q.x then
      return p.y < q.y
    end
    return p.x < q.x
  end)

  local lower = {}
  for i = 1, #points do
    local p = points[i]
    while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
      table.remove(lower)
    end
    lower[#lower + 1] = p
  end

  local upper = {}
  for i = #points, 1, -1 do
    local p = points[i]
    while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
      table.remove(upper)
    end
    upper[#upper + 1] = p
  end

  table.remove(lower)
  table.remove(upper)
  for i = 1, #upper do
    lower[#lower + 1] = upper[i]
  end

  return lower
end

local function makeAsteroidPolygonCoords(radius)
  local vertexCount = love.math.random(7, 8)
  local points = {}
  local tau = math.pi * 2
  local angleJitter = tau / vertexCount * 0.25

  local k1 = love.math.random(2, 4)
  local k2 = love.math.random(5, 7)
  local p1 = MathUtil.randRange(0, tau)
  local p2 = MathUtil.randRange(0, tau)
  local a1 = MathUtil.randRange(0.08, 0.18)
  local a2 = MathUtil.randRange(0.04, 0.10)

  local squash = MathUtil.randRange(0.78, 1.22)
  local rot = MathUtil.randRange(0, tau)

  for i = 1, vertexCount do
    local baseAngle = (i - 1) / vertexCount * tau
    local angle = baseAngle + MathUtil.randRange(-angleJitter, angleJitter)

    local wobble = 1 + a1 * math.sin(k1 * angle + p1) + a2 * math.sin(k2 * angle + p2)
    local r = radius * wobble * MathUtil.randRange(0.78, 1.05)

    local x = math.cos(angle) * r
    local y = math.sin(angle) * r
    local rx, ry = MathUtil.rotate(x, y, rot)
    points[#points + 1] = { x = rx * squash, y = ry / squash }
  end

  local hull = convexHull(points)
  local coords = {}
  for i = 1, #hull do
    coords[#coords + 1] = hull[i].x
    coords[#coords + 1] = hull[i].y
  end

  return coords
end

local function makeAsteroidSurfaceDots(radius)
  local n = love.math.random(math.max(14, math.floor(radius * 0.55)), math.max(18, math.floor(radius * 0.95)))
  n = math.min(n, 44)

  local dots = {}
  for i = 1, n do
    local a = MathUtil.randRange(0, math.pi * 2)
    local dist = MathUtil.randRange(0, radius * 0.78)
    local x = math.cos(a) * dist
    local y = math.sin(a) * dist

    dots[i] = {
      x = x,
      y = y,
      r = MathUtil.randRange(0.7, 1.9) + radius * 0.01,
      v = MathUtil.randSigned(),
      a = MathUtil.randRange(0.04, 0.14),
    }
  end

  return dots
end

local function makeAsteroidSurfaceScratches(radius)
  local n = love.math.random(4, 9)
  local scratches = {}

  for i = 1, n do
    local a = MathUtil.randRange(0, math.pi * 2)
    local dist = MathUtil.randRange(0, radius * 0.65)
    local x = math.cos(a) * dist
    local y = math.sin(a) * dist

    scratches[i] = {
      x = x,
      y = y,
      ang = MathUtil.randRange(0, math.pi * 2),
      len = MathUtil.randRange(radius * 0.10, radius * 0.45),
      w = MathUtil.randRange(0.9, 2.4),
      v = MathUtil.randSigned(),
      a = MathUtil.randRange(0.04, 0.14),
    }
  end

  return scratches
end

local function makeAsteroidRenderCoords(radius)
  local tau = math.pi * 2
  local n = love.math.random(26, 40)

  local k1 = love.math.random(2, 4)
  local k2 = love.math.random(5, 8)
  local k3 = love.math.random(9, 13)
  local p1 = MathUtil.randRange(0, tau)
  local p2 = MathUtil.randRange(0, tau)
  local p3 = MathUtil.randRange(0, tau)
  local a1 = MathUtil.randRange(0.10, 0.20)
  local a2 = MathUtil.randRange(0.05, 0.12)
  local a3 = MathUtil.randRange(0.02, 0.07)

  local squash = MathUtil.randRange(0.78, 1.22)
  local rot = MathUtil.randRange(0, tau)

  local dentCount = love.math.random(2, 5)
  local dents = {}
  for i = 1, dentCount do
    dents[i] = {
      a = MathUtil.randRange(0, tau),
      w = MathUtil.randRange(0.18, 0.42),
      d = MathUtil.randRange(0.06, 0.18),
    }
  end

  local coords = {}
  for i = 1, n do
    local t = (i - 1) / n * tau

    local wobble = 1
      + a1 * math.sin(k1 * t + p1)
      + a2 * math.sin(k2 * t + p2)
      + a3 * math.sin(k3 * t + p3)

    local dent = 0
    for j = 1, dentCount do
      local dd = dents[j]
      local da = MathUtil.normalizeAngle(t - dd.a)
      local x = math.abs(da) / dd.w
      if x < 1 then
        dent = math.max(dent, (1 - x) * dd.d)
      end
    end

    local r = radius * (wobble - dent) * MathUtil.randRange(0.97, 1.03)
    local x = math.cos(t) * r
    local y = math.sin(t) * r
    local rx, ry = MathUtil.rotate(x, y, rot)
    coords[#coords + 1] = rx * squash
    coords[#coords + 1] = ry / squash
  end

  return coords
end

function factory.createWalls(physicsWorld, w, h)
  local margin = 0

  local body = love.physics.newBody(physicsWorld, 0, 0, "static")
  local shape = love.physics.newChainShape(true,
    margin, margin,
    w - margin, margin,
    w - margin, h - margin,
    margin, h - margin
  )

  local fixture = love.physics.newFixture(body, shape)
  fixture:setRestitution(1.0)
  fixture:setFriction(0.0)

  return body
end

function factory.createShip(ecsWorld, physicsWorld, x, y)
  local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
  body:setLinearDamping(0.15)
  body:setAngularDamping(6.0)
  body:setBullet(true)

  local shape = love.physics.newPolygonShape(
    22, 0,
    10, 9,
    0, 16,
    -18, 8,
    -22, 0,
    -18, -8,
    0, -16,
    10, -9
  )

  local fixture = love.physics.newFixture(body, shape, 1)
  fixture:setDensity(4)
  body:resetMassData()
  fixture:setRestitution(0.2)
  fixture:setFriction(0.4)

  fixture:setCategory(2)

  local e = ecsWorld:newEntity()
    :give("physics_body", body, shape, fixture)
    :give("renderable", "ship", { 0.75, 0.85, 1.0, 1.0 })
    :give("ship")
    :give("ship_control", 220, 180, 3000, 2.0, 1400)
    :give("ship_input")
    :give("auto_cannon")
    :give("engine_trail", {
      offsetX = -24,
      offsetY = 0,
      color = { 0.00, 1.00, 1.00, 0.95 },
    })
    :give("cargo", 100)
    :give("cargo_hold", 4, 4)
    :give("magnet", 260, 85, 26, 320)
    :give("hull", 100)
    :give("shield", 60, 0)
    :give("energy", 100, 0)

  fixture:setUserData(e)

  if e.cargo and e.cargo_hold and e.cargo_hold.slots then
    e.cargo.used = Inventory.totalVolume(e.cargo_hold.slots)
  end

  return e
end

function factory.createPlayer(ecsWorld, ship)
  local e = ecsWorld:newEntity()
    :give("player")
    :give("pilot", ship)
    :give("player_progress", 1, 0, 100)

  return e
end

function factory.createAsteroid(ecsWorld, physicsWorld, x, y, radius)
  local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
  body:setLinearDamping(0.02)
  body:setAngularDamping(0.01)

  local coords = makeAsteroidPolygonCoords(radius)
  local shape = love.physics.newPolygonShape(unpack(coords))
  local fixture = love.physics.newFixture(body, shape, 1)
  fixture:setRestitution(0.9)
  fixture:setFriction(0.4)

  fixture:setCategory(1)

  body:setLinearVelocity(MathUtil.randRange(-8, 8), MathUtil.randRange(-8, 8))
  body:setAngularVelocity(MathUtil.randRange(-0.12, 0.12))

  local craters = {}

  local rng = love.math.newRandomGenerator(love.math.random(1, 1000000))
  local color = pickAsteroidColor(rng)

  local maxHealth = math.floor(30 + radius * 2)

  local seed = love.math.random(1, 1000000)

  local e = ecsWorld:newEntity()
    :give("physics_body", body, shape, fixture)
    :give("renderable", "asteroid", color)
    :give("asteroid", radius, craters, nil, nil, nil, nil, seed)
    :give("health", maxHealth)

  fixture:setUserData(e)

  return e
end

function factory.spawnAsteroids(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius)
  avoidRadius = avoidRadius or 0
  local padding = 40

  for _ = 1, count do
    local radius = MathUtil.randRange(18, 46)

    local x, y
    for _ = 1, 20 do
      local candidateX = MathUtil.randRange(radius + padding, w - radius - padding)
      local candidateY = MathUtil.randRange(radius + padding, h - radius - padding)

      x, y = candidateX, candidateY

      if avoidX ~= nil and avoidY ~= nil and avoidRadius > 0 then
        local dx = candidateX - avoidX
        local dy = candidateY - avoidY
        local minDist = avoidRadius + radius
        if (dx * dx + dy * dy) >= (minDist * minDist) then
          break
        end
      else
        break
      end
    end

    factory.createAsteroid(ecsWorld, physicsWorld, x, y, radius)
  end
end

return factory
