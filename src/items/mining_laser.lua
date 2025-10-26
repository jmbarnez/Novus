---@diagnostic disable: undefined-global
-- Mining Laser Turret item definition - links to turret module logic

return {
    id = "mining_laser_turret",
    name = "Mining Laser",
    description = "A precision mining laser for extracting resources from asteroids. Deals moderate damage.",
    stackable = false,
    value = 100,
    type = "turret",
    volume = 0.15, -- 0.15 cubic meters for mining laser
    module = require("src.turret_modules.mining_laser"),
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
