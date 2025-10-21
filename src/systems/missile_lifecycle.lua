-- Missile Lifecycle System
-- Manages missile aging and self-destruct when max age is reached

local ECS = require('src.ecs')

local MissileLifecycleSystem = {
    name = "MissileLifecycleSystem",
    priority = 5  -- Run before destruction system
}

function MissileLifecycleSystem.update(dt)
    -- This system is no longer used - missile lifecycle is now handled by MissileSystem
    -- which calls MissileLauncher module functions
end

return MissileLifecycleSystem
