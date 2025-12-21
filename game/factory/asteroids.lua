local asteroids = {}

local unpack = table.unpack or rawget(_G, "unpack")

local MathUtil = require("util.math")
local Rng = require("util.rng")

local ORE_VARIANTS = {
  { id = "iron",    tint = { 0.72, 0.72, 0.74, 1.0 } },
  { id = "mithril", tint = { 0.22, 0.28, 0.46, 1.0 } },
}

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

local function mulColor(a, b)
  return {
    MathUtil.clamp((a[1] or 1) * (b[1] or 1), 0, 1),
    MathUtil.clamp((a[2] or 1) * (b[2] or 1), 0, 1),
    MathUtil.clamp((a[3] or 1) * (b[3] or 1), 0, 1),
    MathUtil.clamp((a[4] or 1) * (b[4] or 1), 0, 1),
  }
end

local function mixColor(a, b, t)
  return {
    MathUtil.clamp((a[1] or 0) * (1 - t) + (b[1] or 0) * t, 0, 1),
    MathUtil.clamp((a[2] or 0) * (1 - t) + (b[2] or 0) * t, 0, 1),
    MathUtil.clamp((a[3] or 0) * (1 - t) + (b[3] or 0) * t, 0, 1),
    MathUtil.clamp(((a[4] or 1) * (1 - t) + (b[4] or 1) * t), 0, 1),
  }
end

local function pickOreVariant(rng)
  return ORE_VARIANTS[rng:random(1, #ORE_VARIANTS)]
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

local function makeAsteroidPolygonCoords(rng, radius)
  local vertexCount = rng:random(7, 8)
  local points = {}
  local tau = math.pi * 2
  local angleJitter = tau / vertexCount * 0.25

  local k1 = rng:random(2, 4)
  local k2 = rng:random(5, 7)
  local p1 = MathUtil.randRangeRng(rng, 0, tau)
  local p2 = MathUtil.randRangeRng(rng, 0, tau)
  local a1 = MathUtil.randRangeRng(rng, 0.08, 0.18)
  local a2 = MathUtil.randRangeRng(rng, 0.04, 0.10)

  local squash = MathUtil.randRangeRng(rng, 0.78, 1.22)
  local rot = MathUtil.randRangeRng(rng, 0, tau)

  for i = 1, vertexCount do
    local baseAngle = (i - 1) / vertexCount * tau
    local angle = baseAngle + MathUtil.randRangeRng(rng, -angleJitter, angleJitter)

    local wobble = 1 + a1 * math.sin(k1 * angle + p1) + a2 * math.sin(k2 * angle + p2)
    local r = radius * wobble * MathUtil.randRangeRng(rng, 0.78, 1.05)

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

local function makeAsteroidRenderCoords(rng, radius)
  local tau = math.pi * 2
  local n = rng:random(26, 40)

  local k1 = rng:random(2, 4)
  local k2 = rng:random(5, 8)
  local k3 = rng:random(9, 13)
  local p1 = MathUtil.randRangeRng(rng, 0, tau)
  local p2 = MathUtil.randRangeRng(rng, 0, tau)
  local p3 = MathUtil.randRangeRng(rng, 0, tau)
  local a1 = MathUtil.randRangeRng(rng, 0.10, 0.20)
  local a2 = MathUtil.randRangeRng(rng, 0.05, 0.12)
  local a3 = MathUtil.randRangeRng(rng, 0.02, 0.07)

  local squash = MathUtil.randRangeRng(rng, 0.78, 1.22)
  local rot = MathUtil.randRangeRng(rng, 0, tau)

  local dentCount = rng:random(2, 5)
  local dents = {}
  for i = 1, dentCount do
    dents[i] = {
      a = MathUtil.randRangeRng(rng, 0, tau),
      w = MathUtil.randRangeRng(rng, 0.18, 0.42),
      d = MathUtil.randRangeRng(rng, 0.06, 0.18),
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

    local r = radius * (wobble - dent) * MathUtil.randRangeRng(rng, 0.97, 1.03)
    local x = math.cos(t) * r
    local y = math.sin(t) * r
    local rx, ry = MathUtil.rotate(x, y, rot)
    coords[#coords + 1] = rx * squash
    coords[#coords + 1] = ry / squash
  end

  return coords
end

function asteroids.createAsteroid(ecsWorld, physicsWorld, x, y, radius, rng, oreId)
  rng = Rng.ensure(rng)
  local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
  body:setLinearDamping(0.02)
  body:setAngularDamping(0.01)

  local coords = makeAsteroidPolygonCoords(rng, radius)
  local shape = love.physics.newPolygonShape(unpack(coords))
  local fixture = love.physics.newFixture(body, shape, 1)
  fixture:setRestitution(0.9)
  fixture:setFriction(0.4)

  fixture:setCategory(1)

  body:setLinearVelocity(MathUtil.randRangeRng(rng, -8, 8), MathUtil.randRangeRng(rng, -8, 8))
  body:setAngularVelocity(MathUtil.randRangeRng(rng, -0.12, 0.12))

  local craters = {}

  local baseColor = pickAsteroidColor(rng)
  local color = baseColor
  local finalOreId = oreId
  if finalOreId then
    for i = 1, #ORE_VARIANTS do
      local v = ORE_VARIANTS[i]
      if v and v.id == finalOreId then
        local mixed = mixColor(baseColor, v.tint, 0.68)
        color = mulColor(mixed, { 1.05, 1.05, 1.05, 1.0 })
        break
      end
    end
  end

  local r = radius or 0
  local volume = math.max(1, math.floor((r * r) / 50))
  local maxHealth = math.max(1, math.floor(6 + volume * 2))

  local seed = rng:random(1, 1000000)

  local e = ecsWorld:newEntity()
      :give("physics_body", body, shape, fixture)
      :give("renderable", "asteroid", color)
      :give("asteroid", radius, craters, nil, nil, nil, nil, seed, finalOreId)
      :give("health", maxHealth)

  fixture:setUserData(e)

  return e
end

function asteroids.spawnAsteroids(ecsWorld, physicsWorld, count, w, h, avoidX, avoidY, avoidRadius, rng)
  rng = Rng.ensure(rng)
  avoidRadius = avoidRadius or 0
  local padding = 40

  local oreChance = 0.22

  for _ = 1, count do
    local radius = MathUtil.randRangeRng(rng, 18, 46)

    local x, y
    for _ = 1, 20 do
      local candidateX = MathUtil.randRangeRng(rng, radius + padding, w - radius - padding)
      local candidateY = MathUtil.randRangeRng(rng, radius + padding, h - radius - padding)

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

    local oreId = nil
    if rng:random() < oreChance then
      local v = pickOreVariant(rng)
      oreId = v and v.id or nil
    end
    asteroids.createAsteroid(ecsWorld, physicsWorld, x, y, radius, rng, oreId)
  end
end

return asteroids
