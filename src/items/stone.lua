---@diagnostic disable: undefined-global
-- Stone item definition - Self-contained with data and methods

return {
    -- Item Data (can be modified at runtime)
    id = "stone",
    name = "Stone",
    description = "A chunk of common asteroid stone. Basic building material.",
    stackable = true,
    value = 1,
    volume = 0.001, -- 1 liter per unit
    
    -- Visual/Design properties
    design = {
        shape = "custom",
        size = 10,
        color = {0.6, 0.55, 0.5, 1} -- Brownish stone color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        local size = self.design.size
        -- Main stone body (angular, jagged rock)
        love.graphics.setColor(0.55, 0.5, 0.45, 1)
        love.graphics.polygon("fill", x - size/2, y - size/3, x + size/2, y - size/4, x + size/2.5, y + size/2.5, x - size/2.5, y + size/2)
        
        -- Light edges for 3D effect
        love.graphics.setColor(0.75, 0.7, 0.65, 0.9)
        love.graphics.polygon("fill", x - size/2, y - size/3, x + size/3, y - size/4, x + size/4, y)
        
        -- Dark shadow for depth
        love.graphics.setColor(0.35, 0.3, 0.25, 0.7)
        love.graphics.polygon("fill", x, y + size/4, x + size/2.5, y + size/2.5, x - size/2.5, y + size/2)
        
        -- Additional texture detail
        love.graphics.setColor(0.45, 0.4, 0.35, 0.5)
        love.graphics.polygon("fill", x - size/4, y + size/6, x + size/5, y + size/4, x - size/6, y + size/3)
    end,
    
    -- Update method - called by item system (if needed)
    update = function(self, dt)
        -- Stone doesn't have special update logic
    end,
    
    -- Collection callback - called when player collects item
    onCollect = function(self, playerId)
        -- Could add effects, sounds, etc. here
        -- For now, just a hook for future expansion
    end
}
