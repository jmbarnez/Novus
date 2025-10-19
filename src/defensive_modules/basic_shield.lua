---@diagnostic disable: undefined-global
-- Basic Shield Module
-- Provides additional shield HP overlay on top of hull

local ECS = require('src.ecs')
local Components = require('src.components')

local BasicShield = {
    name = "basic_shield",
    SHIELD_AMOUNT = 25,  -- Shield HP added
    REGEN_RATE = 5,      -- HP per second when regenerating
    REGEN_DELAY = 3      -- Seconds before shield starts regenerating after damage
}

-- Called when module is equipped
function BasicShield.equip(shipId)
    -- Add or update shield component
    local shield = ECS.getComponent(shipId, "Shield")
    if not shield then
        -- Create new shield with basic shield values
        ECS.addComponent(shipId, "Shield", Components.Shield(
            BasicShield.SHIELD_AMOUNT,
            BasicShield.SHIELD_AMOUNT,
            BasicShield.REGEN_RATE,
            BasicShield.REGEN_DELAY
        ))
    else
        -- Boost existing shield (if stacking multiple defensive modules in future)
        shield.max = shield.max + BasicShield.SHIELD_AMOUNT
        shield.current = math.min(shield.current + BasicShield.SHIELD_AMOUNT, shield.max)
        shield.regenRate = math.max(shield.regenRate, BasicShield.REGEN_RATE)
        shield.regenDelay = math.min(shield.regenDelay, BasicShield.REGEN_DELAY)
    end
    print("[BasicShield] Equipped on ship " .. shipId)
end

-- Called when module is unequipped
function BasicShield.unequip(shipId)
    -- Remove shield component or reduce its value
    if ECS.hasComponent(shipId, "Shield") then
        -- For now, just remove it entirely
        ECS.removeComponent(shipId, "Shield")
    end
    print("[BasicShield] Unequipped from ship " .. shipId)
end

return BasicShield
