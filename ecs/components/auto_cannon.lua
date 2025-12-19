local Concord = require("lib.concord")

Concord.component("auto_cannon", function(c, cooldown, range, damage, projectileSpeed, projectileTtl, miningEfficiency)
  c.cooldown = cooldown or 1.0
  c.timer = 0
  c.range = range or 850
  c.damage = damage or 6
  c.projectileSpeed = projectileSpeed or 1200
  c.projectileTtl = projectileTtl or 1.2
  c.miningEfficiency = miningEfficiency or 0.65
  c.coneHalfAngle = math.rad(6)

  c.coneVisHold = 3.0
  c.coneVisFade = 0.6
  c.coneVis = 0
  c.coneVisLen = 40

  c.target = nil
end)

return true
