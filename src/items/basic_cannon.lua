---@diagnostic disable: undefined-global
-- Basic Cannon Turret item definition

return {
    id = "basic_cannon_turret",
    name = "Basic Cannon",
    description = "A simple kinetic cannon that fires yellow projectiles.",
    stackable = false,
    value = 80,
    type = "turret",
    module = require("src.turret_modules.basic_cannon"),
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
