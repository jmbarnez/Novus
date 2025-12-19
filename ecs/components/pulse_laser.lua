local Concord = require("lib.concord")

Concord.component("pulse_laser", function(c, cooldown, range, coneHalfAngle, damage, beamDuration)
  c.cooldown = cooldown or 0.14
  c.timer = 0
  c.range = range or 700
  c.coneHalfAngle = coneHalfAngle or (math.pi / 180) * 20
  c.damage = damage or 12
  c.beamDuration = beamDuration or 0.06
end)

return true
