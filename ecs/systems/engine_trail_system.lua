local Concord = require("lib.concord")
local MathUtil = require("util.math")

local EngineTrailSystem = Concord.system({
  trails = { "engine_trail", "physics_body" },
})

function EngineTrailSystem:init(world)
  self.world = world
end

function EngineTrailSystem:update(dt)
  for i = self.trails.size, 1, -1 do
    local e = self.trails[i]
    local c = e.engine_trail

    local thrust = (e.ship_input and e.ship_input.thrust) or 0
    local target = (thrust > 0) and 1 or 0
    c.intensity = c.intensity + (target - c.intensity) * math.min(1, dt * 14)

    c.emitting = thrust > 0

    local body = e.physics_body.body
    local x, y = body:getPosition()
    local a = body:getAngle()

    local ox, oy = MathUtil.rotate(c.offsetX, c.offsetY, a)
    local px = x + ox
    local py = y + oy

    self:_updateParticles(c, body, px, py, a, dt)
  end
end

function EngineTrailSystem:_updateParticles(c, body, px, py, a, dt)
  local particles = c.particles
  local pool = c.particlePool
  local maxCount = c.particleMax or 0

  if c.emitting and c.particleRate and c.particleRate > 0 then
    c.particleSpawnAcc = c.particleSpawnAcc + dt * c.particleRate * c.intensity

    local count = math.floor(c.particleSpawnAcc)
    if count > 0 then
      c.particleSpawnAcc = c.particleSpawnAcc - count

      local baseAngle = a + math.pi
      local vx, vy = body:getLinearVelocity()

      for _ = 1, count do
        local pt
        if maxCount > 0 and #particles >= maxCount then
          local idx = c.particleCursor or 1
          if idx < 1 or idx > #particles then
            idx = 1
          end

          pt = particles[idx]
          if not pt then
            pt = {}
            particles[idx] = pt
          end

          idx = idx + 1
          if idx > maxCount then
            idx = 1
          end
          c.particleCursor = idx
        else
          if pool and #pool > 0 then
            pt = pool[#pool]
            pool[#pool] = nil
          else
            pt = {}
          end
          particles[#particles + 1] = pt
        end

        local speed = MathUtil.randRange(c.particleSpeedMin, c.particleSpeedMax)
        local ang = baseAngle + MathUtil.randSigned() * c.particleSpread

        local pvx = math.cos(ang) * speed + vx
        local pvy = math.sin(ang) * speed + vy

        local life = MathUtil.randRange(c.particleLifetime * 0.75, c.particleLifetime * 1.10)
        local size = MathUtil.randRange(c.particleSizeMin, c.particleSizeMax)

        pt.x = px
        pt.y = py
        pt.vx = pvx
        pt.vy = pvy
        pt.age = 0
        pt.life = life
        pt.size = size
      end
    end
  end

  local drag = math.exp(-(c.particleDrag or 0) * dt)
  local jitter = c.particleJitter or 0

  for i = #particles, 1, -1 do
    local p = particles[i]
    p.age = p.age + dt
    if p.age >= p.life then
      local last = particles[#particles]
      particles[i] = last
      particles[#particles] = nil

      if pool then
        pool[#pool + 1] = p
      end

      if c.particleCursor and c.particleCursor > #particles then
        c.particleCursor = 1
      end
    else
      p.vx = p.vx * drag
      p.vy = p.vy * drag

      if jitter > 0 then
        p.vx = p.vx + MathUtil.randSigned() * jitter * dt
        p.vy = p.vy + MathUtil.randSigned() * jitter * dt
      end

      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
    end
  end
end

function EngineTrailSystem:drawWorld()
  love.graphics.push("all")
  love.graphics.setBlendMode("add")

  for i = 1, self.trails.size do
    local e = self.trails[i]
    local c = e.engine_trail

    local r = (c.color and c.color[1]) or 0
    local g = (c.color and c.color[2]) or 1
    local b = (c.color and c.color[3]) or 1

    local particles = c.particles
    for p = 1, #particles do
      local pt = particles[p]
      local t = MathUtil.clamp(pt.age / pt.life, 0, 1)
      local a = (1 - t) * (1 - t) * 0.75
      local size = pt.size * (1 - 0.55 * t)
      love.graphics.setColor(r, g, b, a)
      love.graphics.circle("fill", pt.x, pt.y, size)
    end
  end

  love.graphics.pop()
end

return EngineTrailSystem
