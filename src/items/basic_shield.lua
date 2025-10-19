---@diagnostic disable: undefined-global
-- Basic Shield Module item definition

return {
    id = "basic_shield_module",
    name = "Basic Shield",
    description = "A defensive module that adds a protective energy shield to your hull.",
    stackable = false,
    value = 60,
    type = "defensive",
    design = {
        shape = "custom",
        size = 16,
        color = {0.3, 0.7, 1, 1}
    },
    module = require("src.defensive_modules.basic_shield"),
    draw = function(self, x, y)
        local size = self.design.size
        -- Shield bubble outline
        love.graphics.setColor(0.3, 0.7, 1, 0.8)
        love.graphics.circle("line", x, y, size/2, 32)
        -- Shield core
        love.graphics.setColor(0.5, 0.85, 1, 0.6)
        love.graphics.circle("fill", x, y, size/4, 32)
        -- Shield indicator bars
        love.graphics.setColor(0.3, 0.7, 1, 1)
        love.graphics.line(x - size/3, y - size/4, x - size/4, y - size/3)
        love.graphics.line(x + size/3, y - size/4, x + size/4, y - size/3)
    end,
    update = function(self, dt)
        -- Shield item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
