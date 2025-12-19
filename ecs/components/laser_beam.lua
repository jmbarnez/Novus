local Concord = require("lib.concord")

Concord.component("laser_beam", function(c, duration, startX, startY, endX, endY)
  c.duration = duration or 0.06
  c.t = c.duration

  c.startX = startX or 18
  c.startY = startY or 0
  c.endX = endX or (c.startX + 600)
  c.endY = endY or c.startY
end)

return true
