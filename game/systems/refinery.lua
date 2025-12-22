--- Refinery module
--- Handles ore processing recipes and transactions

local Items = require("game.items")
local Inventory = require("game.inventory")

local Refinery = {}

-- Define processing recipes: input ore -> output ingot
-- ratio: how many ore units to produce 1 ingot
-- processingFee: credits cost per unit processed
-- timePerUnit: seconds to process 1 ingot
-- batchBonuses: discounts for larger batches
local recipes = {
    {
        inputId = "iron",
        outputId = "iron_ingot",
        ratio = 2,                                                        -- 2 iron ore -> 1 iron ingot
        processingFee = 5,                                                -- 5 credits per ingot
        timePerUnit = 3.0,                                                -- 3 seconds per ingot
        batchBonuses = {
            { minQty = 5,  timeMultiplier = 0.90, feeMultiplier = 0.95 }, -- 5+: 10% faster, 5% cheaper
            { minQty = 20, timeMultiplier = 0.75, feeMultiplier = 0.85 }, -- 20+: 25% faster, 15% cheaper
        },
    },
    {
        inputId = "mithril",
        outputId = "mithril_ingot",
        ratio = 3,          -- 3 mithril ore -> 1 mithril ingot
        processingFee = 15, -- 15 credits per ingot
        timePerUnit = 8.0,  -- 8 seconds per ingot (rarer = slower)
        batchBonuses = {
            { minQty = 5,  timeMultiplier = 0.90, feeMultiplier = 0.95 },
            { minQty = 20, timeMultiplier = 0.75, feeMultiplier = 0.85 },
        },
    },
}

-- Get all available recipes
function Refinery.getRecipes()
    local result = {}
    for i, recipe in ipairs(recipes) do
        local inputDef = Items.get(recipe.inputId)
        local outputDef = Items.get(recipe.outputId)
        table.insert(result, {
            inputId = recipe.inputId,
            inputName = inputDef and inputDef.name or recipe.inputId,
            inputColor = inputDef and inputDef.color,
            inputIcon = inputDef and inputDef.icon,
            outputId = recipe.outputId,
            outputName = outputDef and outputDef.name or recipe.outputId,
            outputColor = outputDef and outputDef.color,
            outputIcon = outputDef and outputDef.icon,
            ratio = recipe.ratio,
            processingFee = recipe.processingFee,
            timePerUnit = recipe.timePerUnit or 3.0,
            batchBonuses = recipe.batchBonuses or {},
        })
    end
    return result
end

-- Get how much ore the player has
function Refinery.getPlayerOreCount(ship, oreId)
    if not ship or not ship.cargo_hold then return 0 end

    local itemDef = Items.get(oreId)
    local unitVolume = (itemDef and itemDef.unitVolume) or 1
    local total = 0

    for _, slot in ipairs(ship.cargo_hold.slots) do
        if slot.id == oreId and slot.volume then
            total = total + slot.volume
        end
    end

    return math.floor(total / unitVolume)
end

-- Process ore into ingots
-- quantity = number of OUTPUT ingots to produce
function Refinery.processOre(player, ship, recipeInputId, quantity)
    quantity = quantity or 1
    if not player or not ship then
        return false, "No player or ship"
    end

    -- Find the recipe
    local recipe = nil
    for _, r in ipairs(recipes) do
        if r.inputId == recipeInputId then
            recipe = r
            break
        end
    end

    if not recipe then
        return false, "Unknown recipe"
    end

    local hold = ship.cargo_hold
    local cargo = ship.cargo
    if not hold or not cargo then
        return false, "No cargo hold"
    end

    -- Calculate required ore
    local inputDef = Items.get(recipe.inputId)
    local inputUnitVolume = (inputDef and inputDef.unitVolume) or 1
    local requiredOreUnits = quantity * recipe.ratio
    local requiredOreVolume = requiredOreUnits * inputUnitVolume

    -- Check if player has enough ore
    local oreCount = Refinery.getPlayerOreCount(ship, recipe.inputId)
    if oreCount < requiredOreUnits then
        return false, "Not enough " .. (inputDef and inputDef.name or recipe.inputId)
    end

    -- Calculate processing fee
    local totalFee = quantity * recipe.processingFee
    if player:has("credits") and player.credits.balance < totalFee then
        return false, "Not enough credits (need " .. totalFee .. ")"
    end

    -- Calculate output volume
    local outputDef = Items.get(recipe.outputId)
    local outputUnitVolume = (outputDef and outputDef.unitVolume) or 1
    local outputVolume = quantity * outputUnitVolume

    -- Check cargo space (output replaces input, so net change matters)
    local netVolumeChange = outputVolume - requiredOreVolume
    if netVolumeChange > 0 and cargo.used + netVolumeChange > cargo.capacity then
        return false, "Not enough cargo space"
    end

    -- Remove ore from cargo
    local oreToRemove = requiredOreVolume
    for _, slot in ipairs(hold.slots) do
        if slot.id == recipe.inputId and slot.volume and slot.volume > 0 then
            local take = math.min(slot.volume, oreToRemove)
            slot.volume = slot.volume - take
            oreToRemove = oreToRemove - take
            if slot.volume <= 0 then
                Inventory.clear(slot)
            end
            if oreToRemove <= 0 then break end
        end
    end

    -- Add ingots to cargo
    local remaining = Inventory.addToSlots(hold.slots, recipe.outputId, outputVolume)
    if remaining > 0 then
        -- This shouldn't happen if we checked space correctly, but handle it
        return false, "Could not add ingots to cargo"
    end

    -- Deduct processing fee
    if player:has("credits") then
        player.credits.balance = player.credits.balance - totalFee
    end

    -- Update cargo used
    cargo.used = Inventory.totalVolume(hold.slots)

    local outputName = outputDef and outputDef.name or recipe.outputId
    return true, "Processed " .. quantity .. " " .. outputName
end

return Refinery
