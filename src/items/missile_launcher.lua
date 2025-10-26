---@diagnostic disable: undefined-global
-- Missile Launcher Turret Item Definition

local MissileLauncherItem = {
    id = "missile_launcher_turret",
    name = "Missile Launcher",
    description = "Fires homing missiles that track locked targets. Requires target lock to guide, flies straight otherwise.",
    stackable = false,
    value = 200,
    type = "turret",
    volume = 0.5, -- 0.5 cubic meters for missile launcher (bulky due to missiles)
    module = require("src.turret_modules.missile_launcher"), -- Links to the missile_launcher.lua module
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}

return MissileLauncherItem
