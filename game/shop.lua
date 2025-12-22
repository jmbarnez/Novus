--- Shop module
--- Provides access to all purchasable items and handles transactions

local Items = require("game.items")
local Inventory = require("game.inventory")

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

-- Get base price for an item
function Shop.getPrice(itemId)
    local prices = {
        stone = 5,
        iron = 15,
        mithril = 50,
        iron_ingot = 35,
        mithril_ingot = 120,
    }
    return prices[itemId] or 10
end

-- Get sell price (80% of buy price)
function Shop.getSellPrice(itemId)
    return math.floor(Shop.getPrice(itemId) * 0.8)
end

-- Attempt to buy an item
function Shop.buyItem(player, ship, itemId, quantity)
    quantity = quantity or 1
    if not player or not ship then
        return false, "No player or ship"
    end

    local price = Shop.getPrice(itemId) * quantity

    -- Check credits
    if not player:has("credits") or player.credits.balance < price then
        return false, "Not enough credits"
    end

    -- Check cargo space
    local cargo = ship.cargo
    local hold = ship.cargo_hold
    if not cargo or not hold then
        return false, "No cargo hold"
    end

    local itemDef = Items.get(itemId)
    local unitVolume = (itemDef and itemDef.unitVolume) or 1
    local totalVolume = quantity * unitVolume

    if cargo.used + totalVolume > cargo.capacity then
        return false, "Not enough cargo space"
    end

    -- Find slot to add to
    local added = false
    for i, slot in ipairs(hold.slots) do
        if slot.id == itemId then
            slot.volume = slot.volume + totalVolume
            added = true
            break
        elseif Inventory.isEmpty(slot) then
            slot.id = itemId
            slot.volume = totalVolume
            added = true
            break
        end
    end

    if not added then
        return false, "No available slot"
    end

    -- Deduct credits
    player.credits.balance = player.credits.balance - price
    cargo.used = Inventory.totalVolume(hold.slots)

    return true, "Purchased " .. quantity .. " " .. (itemDef and itemDef.name or itemId)
end

-- Attempt to sell an item
function Shop.sellItem(player, ship, itemId, quantity)
    quantity = quantity or 1
    if not player or not ship then
        return false, "No player or ship"
    end

    local hold = ship.cargo_hold
    local cargo = ship.cargo
    if not hold or not cargo then
        return false, "No cargo hold"
    end

    local itemDef = Items.get(itemId)
    local unitVolume = (itemDef and itemDef.unitVolume) or 1
    local totalVolume = quantity * unitVolume

    -- Find slot with this item
    local slot = nil
    for i, s in ipairs(hold.slots) do
        if s.id == itemId and s.volume >= totalVolume then
            slot = s
            break
        end
    end

    if not slot then
        return false, "Not enough items to sell"
    end

    -- Remove from cargo
    slot.volume = slot.volume - totalVolume
    if slot.volume <= 0 then
        Inventory.clear(slot)
    end

    -- Add credits
    local sellPrice = Shop.getSellPrice(itemId) * quantity
    if player:has("credits") then
        player.credits.balance = player.credits.balance + sellPrice
    end

    cargo.used = Inventory.totalVolume(hold.slots)

    return true, "Sold " .. quantity .. " " .. (itemDef and itemDef.name or itemId)
end

return Shop
