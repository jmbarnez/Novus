local Concord = require("lib.concord")

Concord.component("engine_trail", function(c, opts)
  opts = opts or {}

  c.offsetX = opts.offsetX or -22
  c.offsetY = opts.offsetY or 0

  c.color = opts.color or { 0.45, 0.85, 1.0, 1.0 }

  c.emitting = false
  c.intensity = 0

  c.particles = {}
  c.particlePool = {}
  c.particleCursor = 1
  c.particleSpawnAcc = 0
  c.particleRate = opts.particleRate or 140
  c.particleSpeedMin = opts.particleSpeedMin or 120
  c.particleSpeedMax = opts.particleSpeedMax or 280
  c.particleSpread = opts.particleSpread or (math.rad(18))
  c.particleLifetime = opts.particleLifetime or 0.55
  c.particleMax = opts.particleMax or 160
  c.particleSizeMin = opts.particleSizeMin or 1.5
  c.particleSizeMax = opts.particleSizeMax or 3.25
  c.particleDrag = opts.particleDrag or 2.2
  c.particleJitter = opts.particleJitter or 35
end)

return true
