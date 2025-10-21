-- Missile System - Dispatcher for missile module updates
-- Routes missile updates to their module handlers

local ECS = require('src.ecs')
local MissileLauncher = require('src.turret_modules.missile_launcher')

local MissileSystem = {
    name = "MissileSystem",
    priority = 1.5 -- Run before physics to set acceleration
}

function MissileSystem.update(dt)
    -- Update all missiles with homing behavior
    local homingMissiles = ECS.getEntitiesWith({"MissileHoming", "Position", "Velocity"})
    for _, missileId in ipairs(homingMissiles) do
        MissileLauncher.updateHoming(missileId, dt)
    end
    
    -- Update all missiles with age tracking
    local agedMissiles = ECS.getEntitiesWith({"MissileAge"})
    for _, missileId in ipairs(agedMissiles) do
        MissileLauncher.updateAge(missileId, dt)
    end
end

return MissileSystem
