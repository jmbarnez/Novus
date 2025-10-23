local Components = {}

-- Unified AI Component - handles all AI behavior and state
-- @field type string: "combat" (patrol/chase/orbit) or "mining" (mining-specific)
-- @field state string: Current behavior state ("patrol", "chase", "orbit", "mining")
-- @field detectionRadius number: How far to detect targets
-- @field patrolPoints table: Array of waypoints {x, y}
-- @field config table: Behavior-specific configuration
Components.AI = function(config)
    config = config or {}
    return {
        type = config.type or "combat",  -- "combat" or "mining"
        state = config.state or "patrol",
        detectionRadius = config.detectionRadius or 1200,
        patrolPoints = config.patrolPoints or {},
        currentPoint = 1,
        
        -- Behavior state (spawn position, wander angle, orbit direction)
        spawnX = nil,
        spawnY = nil,
        _wanderAngle = nil,
        _wanderTimer = 0,
        orbitDirection = nil,
        
        -- Turret swing state (for idle animation)
        _swingAngle = nil,
        _swingTimer = 0,
        
        -- Aggressive reaction state (when attacked)
        aggressiveTimer = 0,  -- Time remaining in aggressive state
        lastAttacker = nil,   -- Entity ID of last attacker
        aggressiveDuration = 5.0  -- How long to stay aggressive after being attacked
    }
end

return Components
