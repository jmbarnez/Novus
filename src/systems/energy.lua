-- Energy System - Manages ship energy regeneration and module energy consumption
-- Energy powers shields, weapons, and other ship systems

local ECS = require('src.ecs')
local Components = require('src.components')

local EnergySystem = {
    name = "EnergySystem",
    priority = 3  -- Run early to update energy before systems use it
}

-- Energy consumption constants
local ENERGY_CONSUMPTION = {
    shield_regen = 5,      -- per second when shield is regenerating
    mining_laser = 15,     -- per second when firing
    combat_laser = 20,     -- per second when firing
    salvage_laser = 18,    -- per second when firing
    continuous_beam = 20,   -- per second when firing (unified laser)
    basic_cannon = 50,     -- per shot
    missile_launcher = 80, -- per shot
}

function EnergySystem.update(dt)
    -- Update energy for all ships with Energy component
    local energyEntities = ECS.getEntitiesWith({"Energy"})
    
    for _, entityId in ipairs(energyEntities) do
        local energy = ECS.getComponent(entityId, "Energy")
        if not energy then goto continue end
        
        -- Clamp energy to valid range
        energy.current = math.max(0, math.min(energy.current, energy.max))
        
        -- Regenerate energy based on generator module
        if energy.regenRate > 0 then
            energy.current = math.min(energy.current + energy.regenRate * dt, energy.max)
        end
        
        ::continue::
    end
end

-- Consume energy if available, return true if successful
function EnergySystem.consume(energyComp, amount)
    if not energyComp then return false end
    if energyComp.current >= amount then
        energyComp.current = energyComp.current - amount
        return true
    end
    return false
end

-- Get energy percentage
function EnergySystem.getPercent(energyComp)
    if not energyComp or energyComp.max == 0 then return 0 end
    return energyComp.current / energyComp.max
end

-- Store energy consumption table for other systems to access
EnergySystem.CONSUMPTION = ENERGY_CONSUMPTION

return EnergySystem

