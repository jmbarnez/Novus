local Components = {}

-- Cargo component - Represents inventory or cargo bay for the drone/player
-- @field items table: List or map of items and their amounts
-- @field capacity number: Maximum cargo capacity in cubic meters (m3)
-- @field currentVolume number: Current volume usage in cubic meters (m3)
Components.Cargo = function(items, capacity)
    items = items or {}
    local currentVolume = 0

    -- Calculate current volume from existing items
    for itemId, quantity in pairs(items) do
        local ItemLoader = require('src.items.item_loader')
        local itemDef = ItemLoader[itemId]
        if itemDef and itemDef.volume then
            currentVolume = currentVolume + (itemDef.volume * quantity)
        end
    end

    return {
        items = items,
        capacity = capacity or 3.0, -- Default 3 cubic meters for small drones
        currentVolume = currentVolume,

        -- Check if item can be added (returns true if can add, false if would exceed capacity)
        canAddItem = function(self, itemId, quantity)
            quantity = quantity or 1
            local ItemLoader = require('src.items.item_loader')
            local itemDef = ItemLoader[itemId]
            if not itemDef or not itemDef.volume then
                return false -- Unknown item or no volume defined
            end

            local additionalVolume = itemDef.volume * quantity
            return (self.currentVolume + additionalVolume) <= self.capacity
        end,

        -- Add item (only if there's space)
        addItem = function(self, itemId, quantity)
            quantity = quantity or 1
            if not self:canAddItem(itemId, quantity) then
                return false -- Cannot add, capacity exceeded
            end

            local ItemLoader = require('src.items.item_loader')
            local itemDef = ItemLoader[itemId]
            if not itemDef or not itemDef.volume then
                return false -- Unknown item or no volume defined
            end

            self.items[itemId] = (self.items[itemId] or 0) + quantity
            self.currentVolume = self.currentVolume + (itemDef.volume * quantity)
            return true
        end,

        -- Remove item
        removeItem = function(self, itemId, quantity)
            quantity = quantity or 1
            if not self.items[itemId] or self.items[itemId] < quantity then
                return false -- Not enough items to remove
            end

            local ItemLoader = require('src.items.item_loader')
            local itemDef = ItemLoader[itemId]
            if not itemDef or not itemDef.volume then
                return false -- Unknown item or no volume defined
            end

            self.items[itemId] = self.items[itemId] - quantity
            self.currentVolume = self.currentVolume - (itemDef.volume * quantity)

            if self.items[itemId] <= 0 then
                self.items[itemId] = nil
            end

            return true
        end,

        -- Get remaining volume capacity
        getRemainingVolume = function(self)
            return self.capacity - self.currentVolume
        end,

        -- Get total item count (for UI compatibility)
        getItemCount = function(self)
            local count = 0
            for _, quantity in pairs(self.items) do
                count = count + quantity
            end
            return count
        end,

        -- Format volume for display (returns formatted string with m3)
        formatVolume = function(self, volume)
            return string.format("%.2f m3", volume or 0)
        end
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

-- Wallet component - Tracks player currency (credits)
-- @field credits number: Current credit balance
Components.Wallet = function(credits)
    return {
        credits = credits or 0
    }
end

return Components
