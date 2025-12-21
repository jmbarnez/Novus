local Concord = require("lib.concord")

Concord.component("space_station", function(c, stationType, radius, dockingPoints)
    c.stationType = stationType or "hub"
    c.radius = radius or 400
    c.dockingPoints = dockingPoints or {}
end)

return true
