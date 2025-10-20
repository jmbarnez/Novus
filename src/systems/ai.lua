---@diagnostic disable: undefined-global
-- AI System - Basic patrol and chase behaviors for enemy drones

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRange = require('src.systems.turret_range')
local Systems = {}

local AI = {
    name = "AISystem",
    priority = 9,
}

local STEERING = 8.0 -- Steering responsiveness for AI (how quickly they reach desired velocity)

-- Simple helper for distance squared
local function distSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

-- Update loop: handle AI states
function AI.update(dt)
    -- Gather player position (assume single player-controlled drone)
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local playerPos = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerPos = ECS.getComponent(input.targetEntity, "Position")
        end
    end

    -- Update all AI-controlled drones
    local enemyEntities = ECS.getEntitiesWith({"AIController", "Position", "Velocity", "Turret"})
    for _, eid in ipairs(enemyEntities) do
        local ai = ECS.getComponent(eid, "AIController")
        local pos = ECS.getComponent(eid, "Position")
        local vel = ECS.getComponent(eid, "Velocity")
        local turret = ECS.getComponent(eid, "Turret")
        local miningAI = ECS.getComponent(eid, "MiningAI")
        local combatAI = ECS.getComponent(eid, "CombatAI")
        if not (ai and pos and vel) then goto continue end

        -- Skip ALL AI processing for mining AI ships - they are handled by EnemyMiningSystem
        -- Check for MiningAI component FIRST to avoid any state changes
        if miningAI then
            print("[AISystem] Skipping miner " .. eid .. " - has MiningAI component")
            goto continue
        end

        -- Combat AI ships use this system for patrol/chase behavior
        -- CombatAI component is optional marker for clarity but not required for processing

        -- Calculate firing range based on turret module's projectile properties
        local fireRange = ai.fireRange -- Start with default from AIController
        if turret and turret.moduleName then
            local moduleRange = TurretRange.getMaxRange(turret.moduleName)
            if moduleRange then
                fireRange = moduleRange -- Use module's range if available
            end
        end

        -- If player exists, check detection and state transitions
        if playerPos then
            local dsq = distSq(pos.x, pos.y, playerPos.x, playerPos.y)
            local dist = math.sqrt(dsq)
            -- Detection radius should be at least roughly the turret firing range so AI can detect
            -- targets at a distance they can engage. Use module range if available.
            local moduleBasedRadius = nil
            if turret and turret.moduleName then
                local moduleRange = TurretRange.getMaxRange(turret.moduleName)
                if moduleRange then
                    -- Use a slightly smaller detection radius to avoid instant engagement at edge cases,
                    -- but generally detection should be near turret range
                    moduleBasedRadius = moduleRange * 0.95
                end
            end
            local effectiveDetectionRadius = ai.detectionRadius
            if moduleBasedRadius then
                effectiveDetectionRadius = math.max(effectiveDetectionRadius or 0, moduleBasedRadius)
            end
            local detectionRadiusSq = (effectiveDetectionRadius * effectiveDetectionRadius)
            
            if dsq < detectionRadiusSq then
                -- Player detected - determine best behavior based on distance
                if dist < fireRange * 0.8 then
                    -- Close enough to orbit and fire effectively
                    ai.state = "orbit"
                else
                    -- Too far - chase to get into range
                    ai.state = "chase"
                end
            else
                -- Player out of detection range - return to patrol
                if ai.state == "chase" or ai.state == "orbit" then
                    ai.state = "patrol"
                end
            end
        end

        -- Patrol and fallback wandering if needed
        if ai.state == "patrol" then
            -- Store spawn position if not defined
            ai.spawnX = ai.spawnX or pos.x
            ai.spawnY = ai.spawnY or pos.y
            if #ai.patrolPoints > 0 then
                local target = ai.patrolPoints[ai.currentPoint]
                if not target then goto continue end
                local dx = target.x - pos.x
                local dy = target.y - pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < 10 then
                    ai.currentPoint = ai.currentPoint % #ai.patrolPoints + 1
                else
                        -- Normalize and set desired velocity toward point (simple behavior)
                        local desiredVx = (dx / dist) * ai.speed
                        local desiredVy = (dy / dist) * ai.speed
                        local acc = ECS.getComponent(eid, "Acceleration")
                        if acc then
                            acc.ax = (desiredVx - vel.vx) * STEERING
                            acc.ay = (desiredVy - vel.vy) * STEERING
                        end
                end
            else
                -- NO VALID PATROL POINTS: gentle wandering near spawn
                local wanderRadius = 150
                local speed = ai.speed * 0.3
                -- Calculate distance from spawn, nudge back if too far
                local dx = pos.x - ai.spawnX
                local dy = pos.y - ai.spawnY
                local distsq = dx*dx + dy*dy
                if distsq > wanderRadius * wanderRadius then
                    local dist = math.sqrt(distsq)
                    vel.vx = (-dx / dist) * speed
                    vel.vy = (-dy / dist) * speed
                else
                    -- Random gentle drift - change direction less frequently for smoother movement
                    ai._wanderTimer = (ai._wanderTimer or 0) - dt
                    if not ai._wanderAngle or ai._wanderTimer <= 0 then
                        ai._wanderAngle = math.random() * 2 * math.pi
                        ai._wanderTimer = 4 + math.random() * 6  -- Change direction every 4-10 seconds
                    end
                    vel.vx = math.cos(ai._wanderAngle) * speed
                    vel.vy = math.sin(ai._wanderAngle) * speed
                end
            end
        elseif ai.state == "chase" and playerPos then
            -- Move toward player and potentially fire turret
            local dx = playerPos.x - pos.x
            local dy = playerPos.y - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Always move toward player when in chase state
            if dist > 0 then
                    local desiredVx = (dx / dist) * ai.speed
                    local desiredVy = (dy / dist) * ai.speed
                    local acc = ECS.getComponent(eid, "Acceleration")
                    if acc then
                        acc.ax = (desiredVx - vel.vx) * STEERING
                        acc.ay = (desiredVy - vel.vy) * STEERING
                    end
            end
            
            -- Aim and fire turret at player if within firing range
            if turret and turret.moduleName and dist < fireRange then
                local TurretSystem = ECS.getSystem("TurretSystem")
                if TurretSystem and TurretSystem.fireTurret then
                    TurretSystem.fireTurret(eid, playerPos.x, playerPos.y, dt)
                end
            end
        elseif ai.state == "orbit" and playerPos then
            -- Orbit player at optimal turret range
            local dx = playerPos.x - pos.x
            local dy = playerPos.y - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 0 then
                -- Calculate optimal orbit distance (80% of turret range for good firing position)
                local optimalDistance = fireRange * 0.6
                local orbitSpeed = ai.speed * 0.7  -- Slightly slower for better control
                
                -- Calculate perpendicular direction for orbiting (90 degrees to player direction)
                local perpX = -dy / dist
                local perpY = dx / dist
                
                -- Add some randomness to orbit direction to make it less predictable
                if not ai.orbitDirection then
                    ai.orbitDirection = math.random() > 0.5 and 1 or -1
                end
                
                -- Apply perpendicular movement for orbiting
                local orbitX = perpX * ai.orbitDirection * orbitSpeed
                local orbitY = perpY * ai.orbitDirection * orbitSpeed
                
                -- Adjust distance to maintain optimal range
                local distanceError = dist - optimalDistance
                local correctionFactor = math.min(1.0, math.abs(distanceError) / optimalDistance)
                local correctionX = (dx / dist) * correctionFactor * orbitSpeed * 0.5
                local correctionY = (dy / dist) * correctionFactor * orbitSpeed * 0.5
                
                if distanceError > 0 then
                    -- Too far - move closer
                        local desiredVx = orbitX - correctionX
                        local desiredVy = orbitY - correctionY
                        local acc = ECS.getComponent(eid, "Acceleration")
                        if acc then
                            acc.ax = (desiredVx - vel.vx) * STEERING
                            acc.ay = (desiredVy - vel.vy) * STEERING
                        end
                else
                    -- Too close - move away
                        local desiredVx = orbitX + correctionX
                        local desiredVy = orbitY + correctionY
                        local acc = ECS.getComponent(eid, "Acceleration")
                        if acc then
                            acc.ax = (desiredVx - vel.vx) * STEERING
                            acc.ay = (desiredVy - vel.vy) * STEERING
                        end
                end
                
                -- Fire turret at player while orbiting
                if turret and turret.moduleName and dist < fireRange then
                    local TurretSystem = ECS.getSystem("TurretSystem")
                    if TurretSystem and TurretSystem.fireTurret then
                        TurretSystem.fireTurret(eid, playerPos.x, playerPos.y, dt)
                    end
                end
            end
        end

        ::continue::
    end
end

return AI
