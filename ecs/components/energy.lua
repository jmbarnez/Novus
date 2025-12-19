local Concord = require("lib.concord")

Concord.component("energy", function(c, max, regen)
  c.max = max or 100
  c.current = c.max
  c.regen = regen or 0
end)

return true
