---@diagnostic disable: undefined-global
-- Combat Laser Turret Item Definition

local CombatLaserItem = {
    id = "combat_laser_turret",
    name = "Combat Laser",
    description = "Fires a high-velocity laser bolt that deals energy damage.",
    type = "turret",
    module = "combat_laser", -- Links to the combat_laser.lua module
    design = {
        color = {1, 0.2, 0.2, 1} -- Red
    },
    draw = function(self, x, y)
        love.graphics.setColor(self.design.color)
        love.graphics.rectangle("fill", x - 10, y - 2, 20, 4)
    end
}

return CombatLaserItem
