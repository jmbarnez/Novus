local Components = {}

-- Cargo component - Represents inventory or cargo bay for the drone/player
-- @field items table: List or map of items and their amounts
-- @field capacity number: Maximum cargo capacity
Components.Cargo = function(items, capacity)
    return {
        items = items or {},
        capacity = capacity or 10 -- Default 10 slots/items
    }
end

-- MagneticField component - Marks entity as having magnetic collection capability
-- @field active boolean: Whether the magnetic field is currently active
-- @field range number: Collection radius
Components.MagneticField = function(range)
    return {
        active = false,
        range = range or 50
    }
end

-- Stack component - Tracks quantity of stacked items
-- @field quantity number: How many items in this stack
Components.Stack = function(quantity)
    return {
        quantity = quantity or 1
    }
end

return Components
