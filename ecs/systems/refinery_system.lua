--- Refinery System
--- Updates smelting jobs on all refinery stations every frame

local Concord = require("lib.concord")
local RefineryQueue = require("game.systems.refinery_queue")

local RefinerySystem = Concord.system({
    pool = { "refinery_queue" }
})

function RefinerySystem:update(dt)
    for _, entity in ipairs(self.pool) do
        RefineryQueue.update(entity, dt)
    end
end

return RefinerySystem
