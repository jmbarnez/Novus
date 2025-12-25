--- Refinery Bay Component
--- Tracks the asteroid container bay attached to a refinery station

local Concord = require("lib.concord")

--- @param openingWidth number Width of the bay opening (max asteroid diameter that fits)
--- @param bayDepth number How deep the bay extends from the station
--- @param bayAngle number Angle where the bay is positioned on the station (radians)
Concord.component("refinery_bay", function(c, openingWidth, bayDepth, bayAngle)
    c.openingWidth = openingWidth or 80
    c.bayDepth = bayDepth or 100
    c.bayAngle = bayAngle or (math.pi / 2)  -- Default: bottom of station

    -- Processing bonuses
    c.efficiencyBonus = 1.5   -- 50% more ore yield
    c.timeMultiplier = 2.5    -- 2.5x longer processing time

    -- Currently processing asteroid job (only one at a time)
    -- { oreId, oreVolume, outputId, quantity, progress, totalTime }
    c.processingJob = nil

    -- Visual feedback timers
    c.acceptedFlash = 0
    c.rejectedFlash = 0

    -- Track the bay sensor fixture for collision detection
    c.sensorFixture = nil
end)

return true
