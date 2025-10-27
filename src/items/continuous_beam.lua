---@diagnostic disable: undefined-global
-- Continuous Beam Module Item Definition
-- A unified laser that can handle combat, mining, and salvaging

return {
    id = "continuous_beam_turret",
    name = "Continuous Beam Module",
    description = "A versatile blue beam weapon capable of combat, mining, and salvaging. Adapts to any target type.",
    stackable = false,
    value = 200,
    type = "turret",
    volume = 0.2, -- 0.2 cubic meters for continuous beam module
    module = require("src.turret_modules.continuous_beam"),
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}

