---@diagnostic disable: undefined-global
-- Iron Ore item definition - Self-contained with data and methods

return {
    -- Item Data (can be modified at runtime)
    id = "iron",
    name = "Iron Ore",
    description = "Raw iron ore from asteroids.",
    stackable = true,
    value = 5,
    
    -- Visual/Design properties
    design = {
        shape = "circle",
        size = 10,
        color = {0.7, 0.4, 0.2, 1} -- Rusty iron color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        love.graphics.setColor(self.design.color)
        love.graphics.circle("fill", x, y, self.design.size / 2)
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
