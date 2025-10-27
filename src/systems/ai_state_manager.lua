-- AI State Manager System - Unified state management and error handling
-- Manages AI state transitions, error recovery, and performance monitoring

local ECS = require('src.ecs')
local Components = require('src.components')

local AIStateManager = {
    name = "AIStateManager",
    priority = 2  -- Run before behavior systems
}

-- State definitions
AIStateManager.STATES = {
    IDLE = "idle",
    PATROL = "patrol",
    CHASE = "chase",
    ORBIT = "orbit",
    AGGRESSIVE = "aggressive",
    MINING = "mining",
    ERROR = "error"
}

-- Error codes
AIStateManager.ERRORS = {
    MISSING_COMPONENTS = "MISSING_COMPONENTS",
    INVALID_STATE_TRANSITION = "INVALID_STATE_TRANSITION",
    PHYSICS_ERROR = "PHYSICS_ERROR",
    BEHAVIOR_ERROR = "BEHAVIOR_ERROR",
    TIMEOUT = "TIMEOUT"
}

-- Initialize AI state for new entities
function AIStateManager.initializeEntity(eid)
    local aiState = ECS.getComponent(eid, "AIState")
    if not aiState then
        ECS.addComponent(eid, "AIState", Components.AIState())
        aiState = ECS.getComponent(eid, "AIState")
    end

    -- Ensure aiState is not nil after adding component
    if not aiState then
        print("ERROR: Failed to create AIState component for entity " .. eid)
        return
    end

    -- Set initial state based on AI component
    local ai = ECS.getComponent(eid, "AI")
    if ai then
        aiState.currentState = ai.state or AIStateManager.STATES.IDLE
        aiState.stateData = {
            aiType = ai.type,
            detectionRadius = ai.detectionRadius,
            patrolPoints = ai.patrolPoints,
            currentPoint = ai.currentPoint
        }
    else
        aiState.currentState = AIStateManager.STATES.IDLE
        aiState.stateData = {}
    end

    AIStateManager.recordStateTransition(aiState, aiState.currentState)
end

-- Update state timers and handle transitions
function AIStateManager.update(dt)
    local entities = ECS.getEntitiesWith({"AIState"})

    for _, eid in ipairs(entities) do
        local aiState = ECS.getComponent(eid, "AIState")
        if not aiState then goto continue end

        -- Update timers
        aiState.stateTimer = aiState.stateTimer + dt
        aiState.lastUpdateTime = love.timer.getTime()
        aiState.updateCount = aiState.updateCount + 1

        -- Handle transition cooldown
        if aiState.transitionCooldown > 0 then
            aiState.transitionCooldown = aiState.transitionCooldown - dt
        end

        -- Error recovery
        if aiState.currentState == AIStateManager.STATES.ERROR then
            AIStateManager.handleErrorState(eid, aiState, dt)
        end

        -- Sync with legacy AI component if present
        AIStateManager.syncWithLegacyAI(eid, aiState)

        ::continue::
    end
end

-- Attempt state transition with validation
function AIStateManager.transitionState(eid, newState, reason)
    local aiState = ECS.getComponent(eid, "AIState")
    if not aiState then
        AIStateManager.setError(eid, AIStateManager.ERRORS.MISSING_COMPONENTS, "AIState component missing")
        return false
    end

    -- Validate transition
    if not AIStateManager.isValidTransition(aiState.currentState, newState) then
        AIStateManager.setError(eid, AIStateManager.ERRORS.INVALID_STATE_TRANSITION,
            string.format("Invalid transition from %s to %s", aiState.currentState, newState))
        return false
    end

    -- Check cooldown
    if aiState.transitionCooldown > 0 then
        return false
    end

    -- Perform transition
    aiState.previousState = aiState.currentState
    aiState.currentState = newState
    aiState.stateTimer = 0
    aiState.errorCode = nil
    aiState.errorMessage = nil
    aiState.transitionCooldown = 0.1  -- Small cooldown to prevent rapid transitions

    AIStateManager.recordStateTransition(aiState, newState, reason)

    return true
end

-- Set error state
function AIStateManager.setError(eid, errorCode, message)
    local aiState = ECS.getComponent(eid, "AIState")
    if not aiState then return end

    aiState.currentState = AIStateManager.STATES.ERROR
    aiState.errorCode = errorCode
    aiState.errorMessage = message
    aiState.stateTimer = 0

    AIStateManager.recordStateTransition(aiState, AIStateManager.STATES.ERROR, "Error: " .. errorCode)
end

-- Handle error state recovery
function AIStateManager.handleErrorState(eid, aiState, dt)
    -- Try to recover after 5 seconds
    if aiState.stateTimer > 5.0 then
        local fallbackState = aiState.previousState or AIStateManager.STATES.IDLE
        AIStateManager.transitionState(eid, fallbackState, "Error recovery")
    end
end

-- Validate state transitions
function AIStateManager.isValidTransition(fromState, toState)
    -- Allow transitions from error to any state
    if fromState == AIStateManager.STATES.ERROR then
        return true
    end

    -- Define valid transitions
    local validTransitions = {
        [AIStateManager.STATES.IDLE] = {AIStateManager.STATES.PATROL, AIStateManager.STATES.CHASE, AIStateManager.STATES.ORBIT},
        [AIStateManager.STATES.PATROL] = {AIStateManager.STATES.IDLE, AIStateManager.STATES.CHASE, AIStateManager.STATES.AGGRESSIVE},
        [AIStateManager.STATES.CHASE] = {AIStateManager.STATES.IDLE, AIStateManager.STATES.ORBIT, AIStateManager.STATES.AGGRESSIVE},
        [AIStateManager.STATES.ORBIT] = {AIStateManager.STATES.IDLE, AIStateManager.STATES.CHASE, AIStateManager.STATES.AGGRESSIVE},
        [AIStateManager.STATES.AGGRESSIVE] = {AIStateManager.STATES.IDLE, AIStateManager.STATES.CHASE},
        [AIStateManager.STATES.MINING] = {AIStateManager.STATES.IDLE, AIStateManager.STATES.AGGRESSIVE}
    }

    local allowed = validTransitions[fromState]
    if not allowed then return false end

    for _, state in ipairs(allowed) do
        if state == toState then return true end
    end

    return false
end

-- Record state transition for debugging
function AIStateManager.recordStateTransition(aiState, newState, reason)
    table.insert(aiState.stateHistory, {
        state = newState,
        timestamp = love.timer.getTime(),
        reason = reason or "Unknown"
    })

    -- Maintain history size limit
    if #aiState.stateHistory > aiState.maxHistorySize then
        table.remove(aiState.stateHistory, 1)
    end
end

-- Sync with legacy AI component
function AIStateManager.syncWithLegacyAI(eid, aiState)
    local ai = ECS.getComponent(eid, "AI")
    if not ai then return end

    -- Sync state
    if ai.state ~= aiState.currentState then
        ai.state = aiState.currentState
    end

    -- Sync aggressive state
    if aiState.currentState == AIStateManager.STATES.AGGRESSIVE then
        ai.aggressiveTimer = math.max(ai.aggressiveTimer or 0, 1.0)
    end
end

-- Performance monitoring and batch operations
AIStateManager.performanceStats = {
    totalTransitions = 0,
    errorCount = 0,
    averageUpdateTime = 0,
    entitiesProcessed = 0
}

-- Batch state updates for performance
function AIStateManager.batchUpdateStates(updates)
    for _, update in ipairs(updates) do
        AIStateManager.transitionState(update.eid, update.newState, update.reason)
    end
end

-- Optimized entity processing with early exits
function AIStateManager.update(dt)
    local entities = ECS.getEntitiesWith({"AIState"})
    local startTime = love.timer.getTime()
    local processedCount = 0

    for _, eid in ipairs(entities) do
        local aiState = ECS.getComponent(eid, "AIState")
        if not aiState then goto continue end

        -- Update timers
        aiState.stateTimer = aiState.stateTimer + dt
        aiState.lastUpdateTime = love.timer.getTime()
        aiState.updateCount = aiState.updateCount + 1

        -- Handle transition cooldown
        if aiState.transitionCooldown > 0 then
            aiState.transitionCooldown = aiState.transitionCooldown - dt
        end

        -- Error recovery (only for error states)
        if aiState.currentState == AIStateManager.STATES.ERROR then
            AIStateManager.handleErrorState(eid, aiState, dt)
        end

        -- Sync with legacy AI component (batched for performance)
        AIStateManager.syncWithLegacyAI(eid, aiState)

        processedCount = processedCount + 1

        ::continue::
    end

    -- Update performance stats
    local endTime = love.timer.getTime()
    local updateTime = endTime - startTime
    AIStateManager.performanceStats.averageUpdateTime =
        (AIStateManager.performanceStats.averageUpdateTime + updateTime) / 2
    AIStateManager.performanceStats.entitiesProcessed = processedCount
end

-- Get current state info with performance metrics
function AIStateManager.getStateInfo(eid)
    local aiState = ECS.getComponent(eid, "AIState")
    if not aiState then return nil end

    return {
        currentState = aiState.currentState,
        previousState = aiState.previousState,
        stateTimer = aiState.stateTimer,
        errorCode = aiState.errorCode,
        errorMessage = aiState.errorMessage,
        updateCount = aiState.updateCount,
        lastUpdateTime = aiState.lastUpdateTime,
        transitionHistorySize = #aiState.stateHistory
    }
end

-- Get system performance statistics
function AIStateManager.getPerformanceStats()
    return {
        totalTransitions = AIStateManager.performanceStats.totalTransitions,
        errorCount = AIStateManager.performanceStats.errorCount,
        averageUpdateTime = AIStateManager.performanceStats.averageUpdateTime,
        entitiesProcessed = AIStateManager.performanceStats.entitiesProcessed,
        statesDefined = 0  -- Count states
    }
end

-- Reset performance statistics
function AIStateManager.resetPerformanceStats()
    AIStateManager.performanceStats = {
        totalTransitions = 0,
        errorCount = 0,
        averageUpdateTime = 0,
        entitiesProcessed = 0
    }
end

return AIStateManager