---@diagnostic disable: undefined-global
-- Stone item definition - Self-contained with data and methods

return {
    -- Item Data (can be modified at runtime)
    id = "stone",
    name = "Stone",
    description = "A chunk of common asteroid stone.",
    stackable = true,
    value = 1,
    
    -- Visual/Design properties
    design = {
        shape = "circle",
        size = 8,
        color = {0.6, 0.55, 0.5, 1} -- Brownish stone color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        love.graphics.setColor(self.design.color)
        love.graphics.circle("fill", x, y, self.design.size / 2)
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
