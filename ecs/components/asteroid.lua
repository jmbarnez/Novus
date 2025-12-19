local Concord = require("lib.concord")

Concord.component("asteroid", function(c, radius, craters, volume, renderCoords, surfaceDots, surfaceScratches, seed)
  c.radius = radius
  c.craters = craters or {}
  c.renderCoords = renderCoords
  c.surfaceDots = surfaceDots
  c.surfaceScratches = surfaceScratches
  c.seed = seed or love.math.random(1, 1000000)

  local r = radius or 0
  c.volume = volume or math.max(1, math.floor((r * r) / 50))

  c.lastMiningEfficiency = 1.0
end)

return true
