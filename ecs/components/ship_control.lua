local Concord = require("lib.concord")

Concord.component("ship_control", function(c, opts)
  opts = opts or {}
  c.thrustForce = opts.thrustForce or 220
  c.strafeForce = opts.strafeForce or 180
  c.rcsPower = opts.rcsPower or 400           -- Maneuvering thruster force
  c.stabilization = opts.stabilization or 1.0 -- How aggressively to stop rotation

  -- Derived values (computed from physics in ship_control_system)
  c.torque = nil
  c.maxAngularSpeed = nil
  c.stabilizeTorque = nil
  c._initialized = false
end)

return true
