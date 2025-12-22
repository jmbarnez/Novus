--- Refinery Queue Component
--- Tracks active smelting jobs on a refinery station

local Concord = require("lib.concord")

Concord.component("refinery_queue", function(c, maxSlots)
    c.maxSlots = maxSlots or 3
    c.jobs = {} -- Array of { recipeInputId, quantity, progress, totalTime, startTime }
end)
