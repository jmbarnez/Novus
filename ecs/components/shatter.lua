local Concord = require("lib.concord")
local MathUtil = require("util.math")

Concord.component("shatter", function(c, opts)
  opts = opts or {}

  c.duration = opts.duration or 0.15
  c.t = c.duration

  c.shards = {}

  local count = opts.count or 7
  local speedMin = opts.speedMin or 140
  local speedMax = opts.speedMax or 320
  local lenMin = opts.lenMin or 2
  local lenMax = opts.lenMax or 6

  for _ = 1, count do
    local a = MathUtil.randRange(0, math.pi * 2)
    local speed = MathUtil.randRange(speedMin, speedMax)

    c.shards[#c.shards + 1] = {
      x = 0,
      y = 0,
      vx = math.cos(a) * speed,
      vy = math.sin(a) * speed,
      len = MathUtil.randRange(lenMin, lenMax),
      ang = a + MathUtil.randSigned() * 0.6,
    }
  end
end)

return true
