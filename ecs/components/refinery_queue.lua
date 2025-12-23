--- Refinery Queue Component
--- Tracks active smelting jobs on a refinery station

local Concord = require("lib.concord")

--- @param maxSlots number|nil Maximum concurrent jobs
--- @param level number|nil Refinery station level (used for work orders)
--- @param workOrders table|nil Optional predefined work orders available at the station
Concord.component("refinery_queue", function(c, maxSlots, level, workOrders)
    c.maxSlots = maxSlots or 3
    c.level = level or 1
    c.workOrders = workOrders or {}
    c.jobs = {} -- Array of { recipeInputId, quantity, progress, totalTime, startTime }
end)
