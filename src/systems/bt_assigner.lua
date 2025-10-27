-- Behavior Tree Assigner System - Dynamically assigns appropriate BTs to entities
-- Based on AI type, current state, and environmental conditions

local ECS = require('src.ecs')
local BehaviorTree = require('src.ai.behavior_tree')
local CombatBT = require('src.ai.combat_bt')
local MiningBT = require('src.ai.mining_bt')
local AIStateManager = require('src.systems.ai_state_manager')

local BTAssigner = {
    name = "BTAssigner",
    priority = 3  -- Run after AIStateManager
}

-- BT templates cache
BTAssigner.templates = {}

-- Initialize BT templates
function BTAssigner.init()
    BTAssigner.templates.combat = {
        patrol = BTAssigner.createCombatPatrolBT(),
        chase = BTAssigner.createCombatChaseBT(),
        orbit = BTAssigner.createCombatOrbitBT(),
        aggressive = BTAssigner.createCombatAggressiveBT()
    }

    BTAssigner.templates.mining = {
        patrol = BTAssigner.createMiningPatrolBT(),
        mining = BTAssigner.createMiningBT(),
        aggressive = BTAssigner.createMiningAggressiveBT()
    }
end

-- Create combat patrol behavior tree
function BTAssigner.createCombatPatrolBT()
    return BehaviorTree.selector({
        -- If player detected and in range, switch to chase
        BehaviorTree.sequence({
            BehaviorTree.condition(function(entity, dt)
                return BTAssigner.isPlayerDetected(entity)
            end),
            BehaviorTree.action(function(entity, dt)
                AIStateManager.transitionState(entity, AIStateManager.STATES.CHASE, "Player detected")
                return BehaviorTree.RUNNING
            end)
        }),
        -- Otherwise, patrol
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")

            if ai and pos and design then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Patrol.update(entity, ai, pos, vel, turret, design, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create combat chase behavior tree
function BTAssigner.createCombatChaseBT()
    return BehaviorTree.sequence({
        -- Continue chasing while player is detected
        BehaviorTree.condition(function(entity, dt)
            return BTAssigner.isPlayerDetected(entity)
        end),
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")
            local playerPos = BTAssigner.getPlayerPosition()

            if ai and pos and design and playerPos then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Chase.update(entity, ai, pos, vel, turret, design, playerPos, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create combat orbit behavior tree
function BTAssigner.createCombatOrbitBT()
    return BehaviorTree.sequence({
        -- Orbit while player is detected
        BehaviorTree.condition(function(entity, dt)
            return BTAssigner.isPlayerDetected(entity)
        end),
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")
            local playerPos = BTAssigner.getPlayerPosition()

            if ai and pos and design and playerPos then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Orbit.update(entity, ai, pos, vel, turret, design, playerPos, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create combat aggressive behavior tree
function BTAssigner.createCombatAggressiveBT()
    return BehaviorTree.sequence({
        -- Stay aggressive for timer duration
        BehaviorTree.condition(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            return ai and ai.aggressiveTimer and ai.aggressiveTimer > 0
        end),
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")
            local playerPos = BTAssigner.getPlayerPosition()

            if ai and pos and design then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Aggressive.update(entity, ai, pos, vel, turret, design, playerPos, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create mining patrol behavior tree
function BTAssigner.createMiningPatrolBT()
    return BehaviorTree.selector({
        -- If asteroids detected, switch to mining
        BehaviorTree.sequence({
            BehaviorTree.condition(function(entity, dt)
                return BTAssigner.isAsteroidDetected(entity)
            end),
            BehaviorTree.action(function(entity, dt)
                AIStateManager.transitionState(entity, AIStateManager.STATES.MINING, "Asteroid detected")
                return BehaviorTree.RUNNING
            end)
        }),
        -- If player detected and aggressive, switch to aggressive
        BehaviorTree.sequence({
            BehaviorTree.condition(function(entity, dt)
                local ai = ECS.getComponent(entity, "AI")
                return BTAssigner.isPlayerDetected(entity) and ai and ai.aggressiveTimer and ai.aggressiveTimer > 0
            end),
            BehaviorTree.action(function(entity, dt)
                AIStateManager.transitionState(entity, AIStateManager.STATES.AGGRESSIVE, "Player detected while aggressive")
                return BehaviorTree.RUNNING
            end)
        }),
        -- Otherwise, patrol
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")

            if ai and pos and design then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Patrol.update(entity, ai, pos, vel, turret, design, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create mining behavior tree
function BTAssigner.createMiningBT()
    return BehaviorTree.selector({
        -- If no asteroids nearby, switch back to patrol
        BehaviorTree.sequence({
            BehaviorTree.condition(function(entity, dt)
                return not BTAssigner.isAsteroidDetected(entity)
            end),
            BehaviorTree.action(function(entity, dt)
                AIStateManager.transitionState(entity, AIStateManager.STATES.PATROL, "No asteroids nearby")
                return BehaviorTree.RUNNING
            end)
        }),
        -- If player detected and aggressive, switch to aggressive
        BehaviorTree.sequence({
            BehaviorTree.condition(function(entity, dt)
                local ai = ECS.getComponent(entity, "AI")
                return BTAssigner.isPlayerDetected(entity) and ai and ai.aggressiveTimer and ai.aggressiveTimer > 0
            end),
            BehaviorTree.action(function(entity, dt)
                AIStateManager.transitionState(entity, AIStateManager.STATES.AGGRESSIVE, "Player detected while mining")
                return BehaviorTree.RUNNING
            end)
        }),
        -- Otherwise, mine
        BehaviorTree.action(function(entity, dt)
            -- Mining behavior implementation
            -- This would integrate with mining systems
            return BehaviorTree.RUNNING
        end)
    })
end

-- Create mining aggressive behavior tree
function BTAssigner.createMiningAggressiveBT()
    return BehaviorTree.sequence({
        -- Stay aggressive for timer duration
        BehaviorTree.condition(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            return ai and ai.aggressiveTimer and ai.aggressiveTimer > 0
        end),
        BehaviorTree.action(function(entity, dt)
            local ai = ECS.getComponent(entity, "AI")
            local pos = ECS.getComponent(entity, "Position")
            local vel = ECS.getComponent(entity, "Velocity")
            local turret = ECS.getComponent(entity, "Turret")
            local design = ECS.getComponent(entity, "ShipDesign")
            local playerPos = BTAssigner.getPlayerPosition()

            if ai and pos and design then
                local Behaviors = require('src.systems.ai_behaviors')
                Behaviors.Aggressive.update(entity, ai, pos, vel, turret, design, playerPos, dt)
            end
            return BehaviorTree.RUNNING
        end)
    })
end

-- Update BT assignments based on current state with performance optimizations
function BTAssigner.update(dt)
    local entities = ECS.getEntitiesWith({"AI", "AIState"})
    local assignmentsMade = 0
    local startTime = love.timer.getTime()

    for _, eid in ipairs(entities) do
        local ai = ECS.getComponent(eid, "AI")
        local aiState = ECS.getComponent(eid, "AIState")
        local btComp = ECS.getComponent(eid, "BehaviorTree")

        if ai and aiState then
            local requiredBT = BTAssigner.getRequiredBT(ai.type, aiState.currentState)

            if requiredBT and (not btComp or not BTAssigner.isCorrectBT(btComp, requiredBT)) then
                BTAssigner.assignBT(eid, requiredBT)
                assignmentsMade = assignmentsMade + 1
            end
        end
    end

    -- Update performance metrics
    local endTime = love.timer.getTime()
    BTAssigner.lastUpdateTime = endTime - startTime
    BTAssigner.assignmentsThisFrame = assignmentsMade
end

-- Get the required BT for given AI type and state
function BTAssigner.getRequiredBT(aiType, state)
    if not BTAssigner.templates[aiType] then
        return nil
    end

    return BTAssigner.templates[aiType][state]
end

-- Check if entity has the correct BT assigned
function BTAssigner.isCorrectBT(btComp, requiredBT)
    -- Simple check - in a more complex system, this could compare BT structures
    return btComp and btComp.root == requiredBT
end

-- Assign a BT to an entity
function BTAssigner.assignBT(eid, bt)
    local btComp = ECS.getComponent(eid, "BehaviorTree")
    if not btComp then
        btComp = ECS.addComponent(eid, "BehaviorTree", {})
    end

    btComp.root = bt
end

-- Helper functions for conditions
function BTAssigner.isPlayerDetected(entity)
    local ai = ECS.getComponent(entity, "AI")
    local pos = ECS.getComponent(entity, "Position")
    local playerPos = BTAssigner.getPlayerPosition()

    if not ai or not pos or not playerPos then
        return false
    end

    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)

    return dist <= (ai.detectionRadius or 1200)
end

function BTAssigner.isAsteroidDetected(entity)
    -- This would check for nearby asteroids
    -- Implementation depends on asteroid detection system
    return false  -- Placeholder
end

function BTAssigner.getPlayerPosition()
    -- Find player entity
    local players = ECS.getEntitiesWith({"Player"})
    if #players > 0 then
        return ECS.getComponent(players[1], "Position")
    end
    return nil
end

-- Initialize templates on module load
BTAssigner.init()

return BTAssigner