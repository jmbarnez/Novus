--- Shop module
--- Provides access to all purchasable items

local Items = require("game.items")

local Shop = {}

-- Get all items available for purchase with prices
function Shop.getItems()
    local shopItems = {}
    for id, def in pairs(Items.all()) do
        table.insert(shopItems, {
            id = id,
            name = def.name or id,
            color = def.color,
            icon = def.icon,
            price = Shop.getPrice(id),
            def = def,
        })
    end
    -- Sort alphabetically
    table.sort(shopItems, function(a, b) return a.name < b.name end)
    return shopItems
end

-- Get base price for an item (placeholder values)
function Shop.getPrice(itemId)
    local prices = {
        stone = 5,
        iron = 15,
        mithril = 50,
        azurite = 35,
        crimsonite = 45,
        luminite = 60,
        verdium = 40,
    }
    return prices[itemId] or 10
end

-- Attempt to buy an item (for now, always succeeds - no currency yet)
function Shop.buyItem(player, itemId, quantity)
    quantity = quantity or 1
    -- TODO: Check player credits and deduct
    -- TODO: Add item to player cargo
    return true, "Purchase successful"
end

return Shop
