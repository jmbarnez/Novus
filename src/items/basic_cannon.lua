---@diagnostic disable: undefined-global
-- Basic Cannon Turret item definition

return {
    id = "basic_cannon_turret",
    name = "Basic Cannon",
    description = "A simple kinetic cannon that fires yellow projectiles.",
    stackable = false,
    value = 80,
    type = "turret",
    design = {
        shape = "custom",
        size = 16,
        color = {1, 0.9, 0.2, 1}
    },
    module = require("src.modules.basic_cannon"),
    draw = function(self, x, y)
        local size = self.design.size
        -- Cannon barrel
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", x - size/4, y - size/2, size/2, size, 4, 4)
        -- Barrel tip (yellow)
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.circle("fill", x, y + size/2, size/4)
        -- Cannon base
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x - size/2, y + size/3, size, size/3, 4, 4)
    end,
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
