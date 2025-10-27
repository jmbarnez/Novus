---@diagnostic disable: undefined-global
-- Crystal Item Definition
-- Rare resource dropped from special crystal asteroids

return {
    -- Item Data
    id = "crystal",
    name = "Crystal",
    description = "A rare crystalline formation rich in energy. Used for advanced crafting.",
    stackable = true,
    value = 50,  -- Valuable resource
    volume = 0.003, -- 3 liters per unit, higher volume due to energy density
    
    -- Visual/Design properties
    design = {
        shape = "custom",
        size = 12,
        color = {0.7, 0.5, 1, 1}  -- Purple crystal color
    },
    
    -- Draw method - called by render system
    draw = function(self, x, y)
        local size = self.design.size
        
        -- Main crystal body
        love.graphics.setColor(0.7, 0.5, 1, 1)
        love.graphics.polygon("fill",
            x, y - size*0.8,
            x - size*0.4, y + size*0.6,
            x + size*0.4, y + size*0.6
        )
        
        -- Shine highlight
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("fill",
            x, y - size*0.6,
            x - size*0.15, y,
            x + size*0.15, y
        )
    end,
    
    -- Update method - called by item system (if needed)
    update = function(self, dt)
        -- Crystal doesn't have special update logic
    end,
    
    -- Collection callback - called when player collects item
    onCollect = function(self, playerId)
        -- Could add special effects here, like bonus credits or experience
    end
}

