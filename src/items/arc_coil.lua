---@diagnostic disable: undefined-global
-- Arc Coil Turret Item Definition

local ArcCoilItem = {
    id = "arc_coil_turret",
    name = "Arc Coil",
    description = "Emits a continuous lightning beam that chains to a nearby foe. Secondary strike deals half damage.",
    stackable = false,
    value = 260,
    type = "turret",
    volume = 0.45,
    module = require("src.turret_modules.arc_coil"),
    update = function(self, dt)
        -- No-op placeholder for future behaviour
    end,
    onCollect = function(self, playerId)
        -- Hook reserved for future expansion
    end
}

return ArcCoilItem

