---@diagnostic disable: undefined-global
-- Salvage Laser Turret item definition - links to turret module logic

return {
    id = "salvage_laser_turret",
    name = "Salvage Laser",
    description = "A specialized laser for harvesting scrap from wreckage. Deals moderate damage to salvageable materials.",
    stackable = false,
    value = 120,
    type = "turret",
    design = {
        shape = "custom",
        size = 16,
        color = {0.2, 1.0, 0.2, 1}
    },
    module = require("src.turret_modules.salvage_laser"),
    draw = function(self, x, y)
        local size = self.design.size
        -- Laser housing (dark metallic)
        love.graphics.setColor(0.1, 0.15, 0.1, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        
        -- Lens barrel (green glow)
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        
        -- Inner lens (brighter)
        love.graphics.setColor(0.4, 1, 0.4, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        
        -- Lens reflection
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        
        -- Power core glow (bottom) - green tint
        love.graphics.setColor(0.2, 1, 0.2, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        
        -- Power core highlight
        love.graphics.setColor(0.4, 1, 0.4, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        
        -- Heat sink details
        love.graphics.setColor(0.12, 0.15, 0.12, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end,
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
