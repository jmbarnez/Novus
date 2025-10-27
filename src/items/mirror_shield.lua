return {
    id = "mirror_shield_module",
    name = "Mirror Shield",
    description = "Creates a temporary mirror that reflects lasers in the cursor direction for a short time.",
    stackable = false,
    value = 180,
    type = "defensive",
    volume = 0.12,
    design = {
        shape = "custom",
        size = 18,
        color = {0.9, 0.9, 0.6, 1}
    },
    module = require("src.defensive_modules.mirror_shield"),
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.9, 0.9, 0.6, 0.9)
        love.graphics.circle("line", x, y, size/2, 24)
        love.graphics.setColor(0.95, 0.95, 0.7, 0.5)
        love.graphics.circle("fill", x, y, size/5, 24)
    end,
    update = function(self, dt) end,
    onCollect = function(self, playerId) end
}
