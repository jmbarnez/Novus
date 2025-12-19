local Concord = require("lib.concord")

Concord.component("hull", function(c, max)
  c.max = max or 100
  c.current = c.max
end)

return true
