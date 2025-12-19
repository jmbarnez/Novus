local Concord = require("lib.concord")

Concord.component("magnet", function(c, range, strength, snapDistance, maxSpeed)
  c.range = range or 240
  c.strength = strength or 70
  c.snapDistance = snapDistance or 22
  c.maxSpeed = maxSpeed or 280
end)

return true
