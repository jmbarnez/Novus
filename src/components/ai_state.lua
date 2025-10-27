local Components = {}

-- AI State Component - Unified state management for AI entities
-- Provides centralized state tracking, transitions, and error handling
-- @field currentState string: Current AI state ("idle", "patrol", "chase", "orbit", "aggressive", "mining", "error")
-- @field previousState string: Previous state for transition tracking
-- @field stateTimer number: Time spent in current state
-- @field errorCode string: Error code if in error state
-- @field errorMessage string: Human-readable error description
-- @field transitionCooldown number: Cooldown before allowing state transitions
-- @field stateData table: State-specific data storage
Components.AIState = function(config)
    config = config or {}
    return {
        currentState = config.currentState or "idle",
        previousState = config.previousState or nil,
        stateTimer = 0,
        errorCode = nil,
        errorMessage = nil,
        transitionCooldown = 0,
        stateData = config.stateData or {},

        -- State transition history for debugging
        stateHistory = {},
        maxHistorySize = 10,

        -- Performance tracking
        updateCount = 0,
        lastUpdateTime = 0
    }
end

return Components