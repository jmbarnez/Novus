local Concord = require("lib.concord")

Concord.component("player_progress", function(c, level, xp, xpToNext)
  c.level = level or 1
  c.xp = xp or 0
  c.xpToNext = xpToNext or 100
end)

return true
