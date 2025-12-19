local Concord = require("lib.concord")

Concord.component("cargo", function(c, capacity)
  c.capacity = capacity or 100
  c.used = 0
end)

return true
