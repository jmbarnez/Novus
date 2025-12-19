local Concord = require("lib.concord")

Concord.component("shield", function(c, max, regen)
  c.max = max or 50
  c.current = c.max
  c.regen = regen or 0
end)

return true
