local Concord = require("lib.concord")

Concord.component("projectile", function(c, damage, ttl, owner, miningEfficiency)
  c.damage = damage or 1
  c.ttl = ttl or 1.0
  c.owner = owner
  c.miningEfficiency = miningEfficiency
end)

return true
