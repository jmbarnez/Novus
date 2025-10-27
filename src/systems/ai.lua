-- Enhanced AI System with unified state management
-- Provides compatibility layer and integrates with AIStateManager
local ECS = require('src.ecs')
local EntityHelpers = require('src.entity_helpers')
local AIStateManager = require('src.systems.ai_state_manager')

local AISystem = {
    name = "AISystem",
    priority = 1  -- Run before AIStateManager
}

function AISystem.triggerAggressiveReaction(victimId, attackerId)
    -- Prefer using EntityHelpers.notifyAIDamage, but support direct calls too
    if not victimId then return end

    local attacker = attackerId
    if attacker then
        -- If attacker is a projectile, resolve owner
        local projectile = ECS.getComponent(attacker, "Projectile")
        if projectile and projectile.ownerId and projectile.ownerId ~= 0 then
            attacker = projectile.ownerId
        else
            local controlledBy = ECS.getComponent(attacker, "ControlledBy")
            if controlledBy and controlledBy.pilotId then attacker = controlledBy.pilotId end
        end
    end

    -- Update legacy AI component
    local ai = ECS.getComponent(victimId, "AI")
    if ai then
        ai.aggressiveTimer = ai.aggressiveDuration or 5.0
        ai.lastAttacker = attacker
        ai.state = "aggressive"
        if ai.type == "mining" then ai._wasMining = true end
    end

    -- Update AIState component
    AIStateManager.transitionState(victimId, AIStateManager.STATES.AGGRESSIVE, "Aggressive reaction triggered")
end

function AISystem.update(dt)
    -- Initialize AIState for entities with AI component but no AIState
    local entities = ECS.getEntitiesWith({"AI"})
    for _, eid in ipairs(entities) do
        local aiState = ECS.getComponent(eid, "AIState")
        if not aiState then
            AIStateManager.initializeEntity(eid)
        end
    end

    -- Handle legacy aggressive timer decay
    local aggressiveEntities = ECS.getEntitiesWith({"AI"})
    for _, eid in ipairs(aggressiveEntities) do
        local ai = ECS.getComponent(eid, "AI")
        local aiState = ECS.getComponent(eid, "AIState")

        if ai and ai.aggressiveTimer and ai.aggressiveTimer > 0 then
            ai.aggressiveTimer = ai.aggressiveTimer - dt

            -- Transition out of aggressive state when timer expires
            if ai.aggressiveTimer <= 0 and aiState and aiState.currentState == AIStateManager.STATES.AGGRESSIVE then
                local fallbackState = ai._wasMining and AIStateManager.STATES.MINING or AIStateManager.STATES.PATROL
                AIStateManager.transitionState(eid, fallbackState, "Aggressive timer expired")
                ai._wasMining = nil
            end
        end
    end
end

return AISystem
