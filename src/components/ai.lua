local Components = {}

-- AIController component - Basic AI state for enemies
-- @field state string: Current AI behavior state ("patrol", "chase", "mining", etc.)
-- @field patrolPoints table: Array of waypoints for patrol behavior
-- @field currentPoint number: Index of current patrol point
-- @field speed number: Movement speed for this AI
-- @field detectionRadius number: Radius to detect player
-- @field fireRange number: Maximum range to fire turret
Components.AIController = function(state, patrolPoints, speed, detectionRadius, fireRange)
    return {
        state = state or "patrol",
        patrolPoints = patrolPoints or {},
        currentPoint = 1,
        speed = speed or 80,
        detectionRadius = detectionRadius or 1200,  -- Much larger detection radius (1200 pixels)
        fireRange = fireRange or 2500  -- Fallback fire range, will be overridden by turret specs
    }
end

-- MiningAI component - Marks an entity as a mining AI ship
-- Purely a marker component to identify mining AI ships for ECS queries
Components.MiningAI = function()
    return {
        isMiner = true
    }
end

-- CombatAI component - Marks an entity as a combat AI ship
-- Purely a marker component to identify combat AI ships for ECS queries
Components.CombatAI = function()
    return {
        isCombat = true
    }
end

return Components
