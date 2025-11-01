-- Turret AI System - Handles stationary defensive turrets
-- Turrets can be owned by player or enemy, and will target accordingly

local ECS = require('src.ecs')
local EntityHelpers = require('src.entity_helpers')
local AiTurretHelper = require('src.systems.ai_turret_helper')
local TurretRegistry = require('src.turret_registry')

local TurretAISystem = {
    name = "TurretAISystem",
    priority = 3  -- Run after AI system but before turret firing
}

local TurretSystem
local function getTurretSystem()
    if not TurretSystem then
        TurretSystem = require('src.systems.turret')
    end
    return TurretSystem
end

-- Find the closest valid target for a turret
-- @param turretId number: The turret entity ID
-- @param pos table: Position component with x, y
-- @param ai table: AI component
-- @return targetPos table|nil: Target position {x, y} or nil if no target
-- @return targetId number|nil: Target entity ID or nil
local function findTarget(turretId, pos, ai)
    if not ai or not pos then return nil, nil end
    
    local detectionRadius = ai.detectionRadius or 1500
    local owner = ai.owner or "player"
    
    local closestTarget = nil
    local closestDistSq = detectionRadius * detectionRadius
    
    -- Player turrets target enemies
    if owner == "player" then
        local enemies = EntityHelpers.getEnemyShips()
        for _, enemyId in ipairs(enemies) do
            local enemyPos = ECS.getComponent(enemyId, "Position")
            local enemyHull = ECS.getComponent(enemyId, "Hull")
            
            if enemyPos and enemyHull and enemyHull.current > 0 then
                local dx = enemyPos.x - pos.x
                local dy = enemyPos.y - pos.y
                local distSq = dx * dx + dy * dy
                
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestTarget = {x = enemyPos.x, y = enemyPos.y}
                    ai.currentTargetId = enemyId
                end
            end
        end
    -- Enemy turrets target player
    elseif owner == "enemy" then
        local playerShipId = EntityHelpers.getPlayerShip()
        if playerShipId then
            local playerPos = ECS.getComponent(playerShipId, "Position")
            local playerHull = ECS.getComponent(playerShipId, "Hull")
            
            if playerPos and playerHull and playerHull.current > 0 then
                local dx = playerPos.x - pos.x
                local dy = playerPos.y - pos.y
                local distSq = dx * dx + dy * dy
                
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestTarget = {x = playerPos.x, y = playerPos.y}
                    ai.currentTargetId = playerShipId
                end
            end
        end
        
        -- Also check player-controlled entities
        local playerShips = EntityHelpers.getPlayerControlledShips()
        for _, shipId in ipairs(playerShips) do
            local shipPos = ECS.getComponent(shipId, "Position")
            local shipHull = ECS.getComponent(shipId, "Hull")
            
            if shipPos and shipHull and shipHull.current > 0 then
                local dx = shipPos.x - pos.x
                local dy = shipPos.y - pos.y
                local distSq = dx * dx + dy * dy
                
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestTarget = {x = shipPos.x, y = shipPos.y}
                    ai.currentTargetId = shipId
                end
            end
        end
    end
    
    -- Check if current target is still valid
    if ai.currentTargetId then
        local targetPos = ECS.getComponent(ai.currentTargetId, "Position")
        local targetHull = ECS.getComponent(ai.currentTargetId, "Hull")
        
        if not targetPos or not targetHull or targetHull.current <= 0 then
            ai.currentTargetId = nil
            if not closestTarget then
                return nil, nil
            end
        elseif closestTarget then
            -- Use the existing target if it's still the closest
            local dx = targetPos.x - pos.x
            local dy = targetPos.y - pos.y
            local currentDistSq = dx * dx + dy * dy
            
            if currentDistSq < closestDistSq then
                closestTarget = {x = targetPos.x, y = targetPos.y}
            end
        end
    end
    
    return closestTarget, ai.currentTargetId
end

-- Update a single turret's AI behavior
-- @param turretId number: The turret entity ID
-- @param dt number: Delta time
local function updateTurret(turretId, dt)
    local pos = ECS.getComponent(turretId, "Position")
    local ai = ECS.getComponent(turretId, "AI")
    local turret = ECS.getComponent(turretId, "Turret")
    
    if not pos or not ai or ai.type ~= "turret" then
        return
    end
    
    -- Ensure velocity is zero (turret cannot move)
    local vel = ECS.getComponent(turretId, "Velocity")
    if vel then
        vel.vx = 0
        vel.vy = 0
    end
    
    -- Find target
    local targetPos, targetId = findTarget(turretId, pos, ai)
    
    if targetPos and turret and turret.moduleName and turret.moduleName ~= "" then
        -- Target found - aim and fire
        local turretModule = TurretRegistry.getModule(turret.moduleName)
        
        -- Try alternative module names if first lookup fails
        if not turretModule and turret.moduleName == "continuous_beam" then
            turretModule = TurretRegistry.getModule("continuous_beam_turret")
        end
        
        if turretModule then
            local dx = targetPos.x - pos.x
            local dy = targetPos.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- Check if target is in range
            local engagementRange = AiTurretHelper.getEffectiveEngagementRange(turretModule, 0.1)
            if dist <= engagementRange then
                -- Aim turret at target
                AiTurretHelper.aimTurretAtTarget(turretId, turret, pos, targetPos)
                
                -- Fire if conditions are met
                if AiTurretHelper.shouldFireThisFrame(turretId, turret, turretModule, dt) then
                    local turretSys = getTurretSystem()
                    if turretSys and turretSys.fireTurret then
                        turretSys.fireTurret(turretId, targetPos.x, targetPos.y, dt)
                        
                        -- Handle continuous weapons (lasers)
                        if turretModule.CONTINUOUS and turretModule.applyBeam then
                            AiTurretHelper.fireLaserAtTarget(turretId, turret, turretModule, targetPos, dt)
                        end
                    end
                end
            else
                -- Target out of range - idle swing
                ai._swingTimer = (ai._swingTimer or 0) - dt
                if not ai._swingAngle or ai._swingTimer <= 0 then
                    ai._swingAngle = math.random() * 2 * math.pi
                    ai._swingTimer = 2 + math.random() * 3
                end
                local swingRadius = 200
                if turret then
                    turret.aimX = pos.x + math.cos(ai._swingAngle) * swingRadius
                    turret.aimY = pos.y + math.sin(ai._swingAngle) * swingRadius
                end
            end
        end
    else
        -- No target - idle swing
        ai._swingTimer = (ai._swingTimer or 0) - dt
        if not ai._swingAngle or ai._swingTimer <= 0 then
            ai._swingAngle = math.random() * 2 * math.pi
            ai._swingTimer = 2 + math.random() * 3
        end
        local swingRadius = 200
        if turret then
            turret.aimX = pos.x + math.cos(ai._swingAngle) * swingRadius
            turret.aimY = pos.y + math.sin(ai._swingAngle) * swingRadius
        end
        
        -- Clear current target
        ai.currentTargetId = nil
    end
end

function TurretAISystem.update(dt)
    -- Find all turret world objects with AI
    local turrets = ECS.getEntitiesWith({"TurretWorldObject", "AI", "Position", "Turret"})
    
    for _, turretId in ipairs(turrets) do
        local ai = ECS.getComponent(turretId, "AI")
        if ai and ai.type == "turret" then
            local success, err = pcall(updateTurret, turretId, dt)
            if not success then
                print("TurretAISystem.update error for turret " .. turretId .. ": " .. tostring(err))
            end
        end
    end
end

return TurretAISystem

