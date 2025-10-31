-- Shield System - Manages shield regeneration and damage handling
-- Shields protect entities by absorbing damage before hull damage

local ECS = require('src.ecs')
local EnergySystem = require('src.systems.energy')

local ShieldSystem = {
    name = "ShieldSystem",
    priority = 4  -- Run after energy system (priority 3) so energy is available
}

function ShieldSystem.update(dt)
    -- Update shield regeneration for all entities with Shield component
    local shieldEntities = ECS.getEntitiesWith({"Shield"})
    
    for _, entityId in ipairs(shieldEntities) do
        local shield = ECS.getComponent(entityId, "Shield")
        if not shield then goto continue_shield end
        
        -- Clamp shield to valid range
        shield.current = math.max(0, math.min(shield.current, shield.max))
        
        -- Count down regen delay timer
        if shield.regenTimer and shield.regenTimer > 0 then
            shield.regenTimer = shield.regenTimer - dt
        else
            -- Try to regenerate if below max and has regen rate
            if shield.regen and shield.regen > 0 and shield.current < shield.max then
                -- Check if we have energy to regenerate shields
                local energy = ECS.getComponent(entityId, "Energy")
                
                if energy and EnergySystem.consume(energy, EnergySystem.CONSUMPTION.shield_regen * dt) then
                    -- Shield regen slows down as it approaches max
                    -- Scale factor: 1.0 at 0%, ~0.3 at 90%, ~0.1 at 99%
                    local shieldPercent = shield.current / shield.max
                    local slowdownFactor = 1.0 - (shieldPercent * shieldPercent * 0.9)  -- Quadratic slowdown
                    
                    local regenAmount = shield.regen * dt * slowdownFactor
                    shield.current = math.min(shield.max, shield.current + regenAmount)
                end
            end
        end
        
        ::continue_shield::
    end
end

-- Apply damage to shield (used by damage systems)
-- Returns remaining damage after shield absorption
function ShieldSystem.takeDamage(entityId, damage)
    local shield = ECS.getComponent(entityId, "Shield")
    if not shield then return damage end
    
    local remainingDamage = damage
    
    if shield.current > 0 then
        local shieldAbsorbed = math.min(damage, shield.current)
        shield.current = shield.current - shieldAbsorbed
        remainingDamage = damage - shieldAbsorbed
        
        -- Reset regen timer after taking damage
        shield.regenTimer = shield.regenDelay or 0
    end
    
    return remainingDamage
end

-- Get shield percentage
function ShieldSystem.getPercent(shieldComp)
    if not shieldComp or shieldComp.max == 0 then return 0 end
    return shieldComp.current / shieldComp.max
end

return ShieldSystem

