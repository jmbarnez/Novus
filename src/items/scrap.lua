---@diagnostic disable: undefined-global
-- Scrap Item - Generic salvageable material from destroyed ships

return {
    -- Item Data
    id = "scrap",
    name = "Scrap",
    description = "Generic salvageable material from destroyed ships and structures.",
    stackable = true,
    value = 2,
    
    -- Visual/Design properties
    design = {
        shape = "custom",
        size = 10,
        color = {0.5, 0.5, 0.5, 1} -- Gray scrap metal color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        local size = self.design.size
        -- Irregular scrap metal pieces
        love.graphics.setColor(0.45, 0.45, 0.45, 1)
        love.graphics.polygon("fill", x - size/2, y - size/2, x + size/2.5, y - size/3, x + size/2, y + size/2.5, x - size/2.5, y + size/2)
        
        -- Reflective highlights for metallic look
        love.graphics.setColor(0.75, 0.75, 0.75, 0.6)
        love.graphics.polygon("fill", x - size/3, y - size/3, x + size/4, y - size/4, x + size/5, y)
        
        -- Dark edges for depth
        love.graphics.setColor(0.25, 0.25, 0.25, 0.8)
        love.graphics.polygon("fill", x, y + size/4, x + size/2, y + size/2.5, x - size/2.5, y + size/2)
    end,
    
    -- Update method
    update = function(self, dt)
        -- Scrap doesn't have special update logic
    end,
    
    -- Collection callback
    onCollect = function(self, playerId)
        -- Scrap collection hooks for future expansion
    end
}

