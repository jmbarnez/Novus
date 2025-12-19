local Concord = require("lib.concord")

Concord.component("health", function(c, max, current)
  c.max = max or 1
  c.current = current or c.max
end)

return true
