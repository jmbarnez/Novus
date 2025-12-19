local Concord = require("lib.concord")

Concord.component("hit_flash", function(c, duration)
  c.duration = duration or 0.12
  c.t = c.duration
end)

return true
