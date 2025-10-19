---@diagnostic disable: undefined-global
-- Combat Alert System - Alerts nearby enemy combat ships when one is attacked
-- Creates emergent gameplay where attacking one enemy can alert others

local ECS = require('src.ecs')

local CombatAlertSystem = {
    name = "CombatAlertSystem",
    priority = 10  -- Run very early before most systems
}

-- Alert radius - how far away enemies can hear combat
local ALERT_RADIUS = 2000

-- Track which enemies have been hit by the player this frame
local recentPlayerAttacks = {}

function CombatAlertSystem.update(dt)
    -- Get the player
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #playerEntities == 0 then return end
    
    local pilotId = playerEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    local playerDroneId = input and input.targetEntity
    
    if not playerDroneId then return end
    
    -- Check all entities with projectiles to see if any were fired by the player
    local projectiles = ECS.getEntitiesWith({"Projectile", "Position"})
    
    for _, projectileId in ipairs(projectiles) do
        local proj = ECS.getComponent(projectileId, "Projectile")
        
        -- Check if this projectile was fired by the player
        if proj and proj.ownerId == playerDroneId then
            local projPos = ECS.getComponent(projectileId, "Position")
            if projPos then
                -- Find all enemies and check if they're hit by or near this projectile
                CombatAlertSystem.checkAndAlertEnemies(projPos.x, projPos.y, playerDroneId)
            end
        end
    end
    
    -- Decay old alerts (optional - keeps recent attacks from being too spammy)
    for enemyId, lastAlertTime in pairs(recentPlayerAttacks) do
        if love.timer.getTime() - lastAlertTime > 5 then  -- 5 second memory
            recentPlayerAttacks[enemyId] = nil
        end
    end
end

-- Check all enemies and alert them if they're near an attack
function CombatAlertSystem.checkAndAlertEnemies(attackX, attackY, playerDroneId)
    local enemies = ECS.getEntitiesWith({"AIController", "Position", "Hull"})
    local currentTime = love.timer.getTime()
    
    for _, enemyId in ipairs(enemies) do
        local enemyPos = ECS.getComponent(enemyId, "Position")
        local ai = ECS.getComponent(enemyId, "AIController")
        -- Skip miners entirely; they should never react to combat alerts
        if ECS.getComponent(enemyId, "MiningAI") then
            goto continue_enemy
        end
        
        if enemyPos and ai then
            local dx = attackX - enemyPos.x
            local dy = attackY - enemyPos.y
            local distToAttack = math.sqrt(dx * dx + dy * dy)
            
            -- If enemy is within alert radius, switch to chase mode
            if distToAttack < ALERT_RADIUS then
                -- Only alert once per 5 seconds to avoid spam
                if not recentPlayerAttacks[enemyId] or (currentTime - recentPlayerAttacks[enemyId] > 5) then
                    ai.state = "chase"
                    recentPlayerAttacks[enemyId] = currentTime
                    print(string.format("[CombatAlert] Enemy %d alerted to player attack at (%.0f, %.0f), %.0f units away", 
                        enemyId, attackX, attackY, distToAttack))
                end
            end
        end
        ::continue_enemy::
    end
end

return CombatAlertSystem
