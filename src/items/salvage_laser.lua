---@diagnostic disable: undefined-global
-- Salvage Laser Turret item definition - links to turret module logic

return {
    id = "salvage_laser_turret",
    name = "Salvage Laser",
    description = "A specialized laser for harvesting scrap from wreckage. Deals moderate damage to salvageable materials.",
    stackable = false,
    value = 120,
    type = "turret",
    volume = 0.15, -- 0.15 cubic meters for salvage laser
    module = require("src.turret_modules.salvage_laser"),
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
