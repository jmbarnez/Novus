---@diagnostic disable: undefined-global
-- Turret Effects System
-- Handles visual effects for special turrets (explosions, pulses, discharges, etc.)
-- Modular system that turrets can plug into

local ECS = require('src.ecs')
local Components = require('src.components')

local TurretEffectsSystem = {
    name = "TurretEffectsSystem",
    priority = 15  -- Run after most systems but before render
}

-- Create a visual effect entity for a turret
-- @param effectType string - Type of effect ("pulse", "discharge", "repulsor", etc.)
-- @param x, y - Center position
-- @param radius - Effect radius
-- @param duration - How long the effect lasts
-- @param color - RGBA color table
function TurretEffectsSystem.createEffect(effectType, x, y, radius, duration, color)
    local effectId = ECS.createEntity()
    
    ECS.addComponent(effectId, "Position", Components.Position(x, y))
    ECS.addComponent(effectId, "Renderable", Components.Renderable("circle", nil, nil, radius, color))
    
    -- TurretEffect component tracks the effect lifecycle
    ECS.addComponent(effectId, "TurretEffect", {
        effectType = effectType,
        initialRadius = radius,
        currentRadius = radius,
        duration = duration,
        timeRemaining = duration,
        active = true,
    })
    
    -- Created turret effect
    
    return effectId
end

-- Update all active turret effects
function TurretEffectsSystem.update(dt)
    local effects = ECS.getEntitiesWith({"TurretEffect", "Position"})
    
    for _, effectId in ipairs(effects) do
        local effect = ECS.getComponent(effectId, "TurretEffect")
        local renderable = ECS.getComponent(effectId, "Renderable")
        
        if effect then
            effect.timeRemaining = effect.timeRemaining - dt
            
            if effect.timeRemaining <= 0 then
                -- Effect expired
                ECS.destroyEntity(effectId)
            else
                -- Update effect based on type
                local progress = effect.timeRemaining / effect.duration -- 1.0 to 0.0
                
                if effect.effectType == "pulse" then
                    -- Pulse expands and fades
                    if renderable then
                        local expandedRadius = effect.initialRadius + (200 * (1 - progress))
                        renderable.radius = expandedRadius
                        renderable.color[4] = progress * 0.8  -- Fade out
                    end
                    
                elseif effect.effectType == "discharge" then
                    -- Discharge flickers and shrinks
                    if renderable then
                        renderable.radius = effect.initialRadius * progress
                        renderable.color[4] = progress * 0.9
                    end
                    
                elseif effect.effectType == "repulsor" then
                    -- Repulsor wave expands outward
                    if renderable then
                        local expandedRadius = effect.initialRadius + (150 * (1 - progress))
                        renderable.radius = expandedRadius
                        renderable.color[4] = progress * 0.7  -- Fade faster
                    end
                    
                elseif effect.effectType == "missile_volley" then
                    -- Missile volley creates a small glow that fades
                    if renderable then
                        renderable.radius = effect.initialRadius * (1 + (1 - progress) * 0.5)
                        renderable.color[4] = progress * 0.6
                    end
                end
            end
        end
    end
end

return TurretEffectsSystem
