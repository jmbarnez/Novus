local Concord = require("lib.concord")

Concord.component("ship_control", function(c, thrustForce, strafeForce, torque, maxAngularSpeed, stabilizeTorque)
  c.thrustForce = thrustForce
  c.strafeForce = strafeForce
  c.torque = torque
  c.maxAngularSpeed = maxAngularSpeed or 3.0
  c.stabilizeTorque = stabilizeTorque or 0
end)

return true
