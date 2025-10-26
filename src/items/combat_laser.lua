---@diagnostic disable: undefined-global
-- Combat Laser Turret Item Definition

local CombatLaserItem = {
    id = "combat_laser_turret",
    name = "Combat Laser",
    description = "A continuous blue combat laser for engaging enemy ships. Deals sustained energy damage.",
    stackable = false,
    value = 150,
    type = "turret",
    volume = 0.2, -- 0.2 cubic meters for combat laser
    module = require("src.turret_modules.combat_laser"), -- Links to the combat_laser.lua module
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}

return CombatLaserItem
