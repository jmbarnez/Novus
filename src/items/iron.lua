---@diagnostic disable: undefined-global
-- Iron Ore item definition - Self-contained with data and methods

return {
    -- Item Data (can be modified at runtime)
    id = "iron",
    name = "Iron Ore",
    description = "Raw iron ore from asteroids. Valuable resource for crafting.",
    stackable = true,
    value = 5,
    
    -- Visual/Design properties
    design = {
        shape = "custom",
        size = 12,
        color = {0.7, 0.4, 0.2, 1} -- Rusty iron color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        local size = self.design.size
        -- Main ore chunk (rusty iron)
        love.graphics.setColor(0.7, 0.35, 0.15, 1)
        love.graphics.polygon("fill", x - size/2, y - size/3, x + size/2, y - size/4, x + size/3, y + size/2, x - size/3, y + size/2)
        
        -- Highlight for depth
        love.graphics.setColor(0.85, 0.5, 0.25, 0.8)
        love.graphics.polygon("fill", x - size/3, y - size/6, x + size/4, y - size/5, x + size/5, y + size/4)
        
        -- Dark shadow for realism
        love.graphics.setColor(0.5, 0.2, 0.1, 0.6)
        love.graphics.polygon("fill", x - size/2, y + size/3, x + size/2, y + size/4, x + size/3, y + size/2)
    end,
    
    -- Update method - called by item system (if needed)
    update = function(self, dt)
        -- Iron doesn't have special update logic
    end,
    
    -- Collection callback - called when player collects item
    onCollect = function(self, playerId)
        -- Could add effects, sounds, etc. here
        -- For now, just a hook for future expansion
    end
}
