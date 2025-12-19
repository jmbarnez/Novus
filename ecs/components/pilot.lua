local Concord = require("lib.concord")

Concord.component("pilot", function(c, ship)
  c.ship = ship
end)

return true
