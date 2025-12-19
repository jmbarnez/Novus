local Concord = require("lib.concord")

Concord.component("pickup", function(c, id, volume)
  c.id = id
  c.volume = volume or 1
end)

return true
