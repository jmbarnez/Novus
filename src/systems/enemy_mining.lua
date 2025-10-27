---@diagnostic disable: undefined-global
-- Enemy Mining System - DEPRECATED: Mining logic moved to behavior tree
-- This system is kept for backward compatibility but mining is now handled by mining_bt.lua

local ECS = require('src.ecs')

local EnemyMiningSystem = {
    name = "EnemyMiningSystem",
    priority = 8  -- Run before destruction system
}

-- DEPRECATED: Mining logic has been moved to src/ai/mining_bt.lua
-- This system now only handles cleanup of any remaining laser beams
function EnemyMiningSystem.update(dt)
    -- This system is deprecated. Mining is now handled by the behavior tree in mining_bt.lua
    -- Keeping minimal cleanup logic for any legacy laser beams
end

-- DEPRECATED: Laser management moved to mining_bt.lua
function EnemyMiningSystem.updateMinerLaser(minerId, startX, startY, endX, endY)
    -- Deprecated - use mining_bt.lua instead
end

-- DEPRECATED: Damage application moved to mining_bt.lua
function EnemyMiningSystem.applyMinerDamage(minerId, asteroidId, asteroidX, asteroidY, dt)
    -- Deprecated - use mining_bt.lua instead
end

-- DEPRECATED: Cleanup moved to mining_bt.lua
function EnemyMiningSystem.destroyMinerLaser(minerId)
    -- Deprecated - use mining_bt.lua instead
end

return EnemyMiningSystem


