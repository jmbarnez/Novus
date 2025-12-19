local Concord = require("lib.concord")
local MathUtil = require("util.math")
local Physics = require("ecs.util.physics")

local ShatterSystem = Concord.system({
  effects = { "shatter", "physics_body" },
})

function ShatterSystem:update(dt)
  for i = self.effects.size, 1, -1 do
    local e = self.effects[i]
    local c = e.shatter

    c.t = c.t - dt
    if c.t <= 0 then
      Physics.destroyPhysics(e)
      e:destroy()
    else
      local t = 1 - (c.t / c.duration)
      local easedT = t * t
      local drag = math.exp(-6 * dt * (1 + easedT * 3))
      local gravity = 120

      for s = 1, #c.shards do
        local sh = c.shards[s]

        sh.vy = sh.vy + gravity * dt

        sh.vx = sh.vx * drag
        sh.vy = sh.vy * drag

        local jitter = 20 * (1 - easedT)
        sh.vx = sh.vx + MathUtil.randSigned() * jitter * dt
        sh.vy = sh.vy + MathUtil.randSigned() * jitter * dt

        sh.x = sh.x + sh.vx * dt
        sh.y = sh.y + sh.vy * dt

        local speed = math.sqrt(sh.vx * sh.vx + sh.vy * sh.vy)
        local spinRate = 1.5 + speed * 0.008
        sh.ang = sh.ang + MathUtil.randSigned() * spinRate * dt * (1 - easedT * 0.7)

        sh.scale = sh.scale or 1
        sh.scale = math.max(0.1, 1 - easedT * 0.6)
      end
    end
  end
end

return ShatterSystem
