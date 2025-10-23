---@diagnostic disable: undefined-global
-- Basic Generator Item Definition
-- Provides additional energy regeneration

return {
    -- Item Data
    id = "basic_generator",
    name = "Basic Generator",
    description = "A basic power generator that increases energy regeneration rate by 3/sec.",
    type = "generator",
    stackable = false,
    value = 15,
    
    -- Visual/Design properties
    design = {
        shape = "custom",
        size = 14,
        color = {1.0, 0.9, 0.2, 1}  -- Yellow/gold color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        local size = self.design.size
        
        -- Outer glow
        love.graphics.setColor(1.0, 0.9, 0.2, 0.6)
        love.graphics.circle("fill", x, y, size)
        
        -- Main generator body (circular)
        love.graphics.setColor(0.8, 0.7, 0.1, 1)
        love.graphics.circle("fill", x, y, size * 0.7)
        
        -- Inner core
        love.graphics.setColor(1.0, 0.95, 0.4, 0.9)
        love.graphics.circle("fill", x, y, size * 0.4)
        
        -- Power indicator lines
        love.graphics.setColor(1.0, 0.9, 0.2, 0.8)
        love.graphics.setLineWidth(1.5)
        -- Draw 4 radial lines to indicate power
        for i = 0, 3 do
            local angle = (i / 4) * math.pi * 2
            local x1 = x + math.cos(angle) * size * 0.3
            local y1 = y + math.sin(angle) * size * 0.3
            local x2 = x + math.cos(angle) * size * 0.6
            local y2 = y + math.sin(angle) * size * 0.6
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)
    end,
    
    -- Module integration
    module = require('src.generator_modules.basic_generator'),
    
    -- Update method
    update = function(self, dt)
        -- Generator doesn't have special update logic
    end,
    
    -- Collection callback
    onCollect = function(self, playerId)
        -- Generator collection hooks for future expansion
    end
}

