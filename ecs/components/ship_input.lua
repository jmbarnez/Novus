local Concord = require("lib.concord")

Concord.component("ship_input", function(c)
  c.thrust = 0
  c.strafe = 0
  c.turn = 0
  c.brake = 0
end)

return true
