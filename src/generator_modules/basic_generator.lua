---@diagnostic disable: undefined-global
-- Basic Generator Module
-- Provides additional energy regeneration

local ECS = require('src.ecs')
local Components = require('src.components')

local BasicGenerator = {
    name = "basic_generator",
    ENERGY_REGEN_BONUS = 3  -- Additional energy/sec on top of base
}

-- Called when module is equipped
function BasicGenerator.equip(shipId)
    -- Get the ship's energy component
    local energy = ECS.getComponent(shipId, "Energy")
    if energy then
        -- Add bonus regeneration to the ship's base regen rate
        energy.regenRate = energy.regenRate + BasicGenerator.ENERGY_REGEN_BONUS
    end
end

-- Called when module is unequipped
function BasicGenerator.unequip(shipId)
    -- Get the ship's energy component
    local energy = ECS.getComponent(shipId, "Energy")
    if energy then
        -- Remove bonus regeneration
        energy.regenRate = math.max(0, energy.regenRate - BasicGenerator.ENERGY_REGEN_BONUS)
    end
end

return BasicGenerator

