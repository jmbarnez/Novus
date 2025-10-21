---@diagnostic disable: undefined-global
-- AI System - Basic patrol and chase behaviors for enemy drones

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRange = require('src.systems.turret_range')
local LineOfSight = nil -- Lazily load to avoid circular dependencies
local Systems = {}

local AI = {
    name = "AISystem",
    priority = 9,
}

local STEERING = 0.8 -- Steering responsiveness for AI (how quickly they reach desired velocity)
-- Lower value = gentler steering, higher value = more aggressive
-- 0.8 gives smooth, predictable drone-like behavior

local ENABLE_LINE_OF_SIGHT = true -- Set to false to disable line-of-sight checks (for debugging)

-- Lazy load LineOfSight to avoid circular dependencies
local function getLineOfSight()
    if not LineOfSight then
        LineOfSight = require('src.systems.line_of_sight')
    end
    return LineOfSight
end

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
            goto continue
        end

        -- Combat AI ships use this system for patrol/chase behavior
        -- CombatAI component is optional marker for clarity but not required for processing

        -- Calculate effective engagement range based on weapon type
        local engagementRange = ai.fireRange -- Start with default from AIController
        if turret and turret.moduleName then
            local turretModule = nil
            local TurretSystem = ECS.getSystem("TurretSystem")
            if TurretSystem and TurretSystem.turretModules then
                turretModule = TurretSystem.turretModules[turret.moduleName]
            end
            
            -- For continuous weapons (lasers), use falloff end distance as effective range
            if turretModule and turretModule.CONTINUOUS then
                if turret.moduleName == "combat_laser" then
                    engagementRange = 800  -- Combat laser falloff end
                elseif turret.moduleName == "mining_laser" then
                    engagementRange = 1350  -- Mining laser falloff end
                elseif turret.moduleName == "salvage_laser" then
                    engagementRange = 1100  -- Salvage laser falloff end
                end
            else
                -- For projectile weapons, use a generous engagement range
                -- Projectiles have no hard range limit, just lifecycle
                engagementRange = 1000  -- Practical engagement range for projectiles
            end
        end

        -- If player exists, check detection and state transitions
        if playerPos then
            local dsq = distSq(pos.x, pos.y, playerPos.x, playerPos.y)
            local dist = math.sqrt(dsq)
            -- Detection radius should be at least roughly the turret firing range so AI can detect
            -- targets at a distance they can engage. Use module range if available.
            local moduleBasedRadius = nil
            -- Use the AI's detection radius directly, not bound to turret range
            local effectiveDetectionRadius = ai.detectionRadius
            local detectionRadiusSq = (effectiveDetectionRadius * effectiveDetectionRadius)

            if dsq < detectionRadiusSq then
                -- Player detected - determine best behavior based on distance
                if dist < engagementRange * 0.8 then
                    -- Close enough to orbit and fire effectively
                    ai.state = "orbit"
                else
                    -- Too far - chase to get into range
                    ai.state = "chase"
                end
                -- When aggro'd, do NOT swing turret randomly
                if turret then
                    turret._swingTimer = nil
                    turret._swingAngle = nil
                end
            else
                -- Player out of detection range - return to patrol
                if ai.state == "chase" or ai.state == "orbit" then
                    ai.state = "patrol"
                end
                -- Swing turret randomly while idle
                if turret then
                    turret._swingTimer = (turret._swingTimer or 0) - dt
                    if not turret._swingAngle or turret._swingTimer <= 0 then
                        turret._swingAngle = math.random() * 2 * math.pi
                        turret._swingTimer = 1 + math.random() * 2 -- Change direction every 1-3 seconds
                    end
                    local swingRadius = 100
                    turret.aimX = pos.x + math.cos(turret._swingAngle) * swingRadius
                    turret.aimY = pos.y + math.sin(turret._swingAngle) * swingRadius
                end
            end
        else
            -- No player: swing turret randomly
            if turret then
                turret._swingTimer = (turret._swingTimer or 0) - dt
                if not turret._swingAngle or turret._swingTimer <= 0 then
                    turret._swingAngle = math.random() * 2 * math.pi
                    turret._swingTimer = 1 + math.random() * 2 -- Change direction every 1-3 seconds
                end
                local swingRadius = 100
                turret.aimX = pos.x + math.cos(turret._swingAngle) * swingRadius
                turret.aimY = pos.y + math.sin(turret._swingAngle) * swingRadius
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
                        -- Normalize and set desired velocity toward point (thrust-based)
                        local desiredVx = (dx / dist) * ai.speed
                        local desiredVy = (dy / dist) * ai.speed
                        
                        -- Use thrust force instead of direct acceleration
                        local ForceUtils = require('src.systems.force_utils')
                        local physics = ECS.getComponent(eid, "Physics")
                        if physics then
                            -- Calculate thrust needed to reach desired velocity
                            local thrustX = (desiredVx - vel.vx) * STEERING * physics.mass
                            local thrustY = (desiredVy - vel.vy) * STEERING * physics.mass
                            ForceUtils.applyForce(eid, thrustX, thrustY)
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
            
            -- Check line of sight to player (optional)
            local hasLineOfSight = true
            if ENABLE_LINE_OF_SIGHT then
                local los_ok, los_result = pcall(function()
                    return getLineOfSight().canSeeTarget(pos.x, pos.y, playerPos.x, playerPos.y, eid)
                end)
                if los_ok then
                    hasLineOfSight = los_result
                end
            end
            
            -- Always move directly toward player when in chase state (thrust-based)
            local moveDx = playerPos.x - pos.x
            local moveDy = playerPos.y - pos.y
            local moveDist = math.sqrt(moveDx*moveDx + moveDy*moveDy)
            
            if moveDist > 0 then
                local desiredVx = (moveDx / moveDist) * ai.speed
                local desiredVy = (moveDy / moveDist) * ai.speed
                
                local ForceUtils = require('src.systems.force_utils')
                local physics = ECS.getComponent(eid, "Physics")
                if physics then
                    local thrustX = (desiredVx - vel.vx) * STEERING * physics.mass
                    local thrustY = (desiredVy - vel.vy) * STEERING * physics.mass
                    ForceUtils.applyForce(eid, thrustX, thrustY)
                end
            end
            
            -- Aim and fire turret at player if within firing range and has line of sight
            if hasLineOfSight and turret and turret.moduleName and dist < engagementRange then
                -- Store turret aim position for rendering
                local fireAngle = math.atan2(dy, dx)
                local muzzleDistance = 12 -- Should match barrelLength in drawTurret
                turret.aimX = pos.x + math.cos(fireAngle) * muzzleDistance
                turret.aimY = pos.y + math.sin(fireAngle) * muzzleDistance

                local TurretSystem = ECS.getSystem("TurretSystem")
                if TurretSystem and TurretSystem.fireTurret then
                    -- Always call fireTurret - it handles heat checks and laser entity management
                    -- This ensures laser entity gets recreated after cooldown completes
                    TurretSystem.fireTurret(eid, playerPos.x, playerPos.y, dt)
                    
                    -- For continuous weapons (lasers), apply beam damage if not overheating
                    local turretModule = TurretSystem.turretModules[turret.moduleName]
                    if turretModule and turretModule.CONTINUOUS and turretModule.applyBeam then
                        -- Check if laser can fire (not overheated)
                        local canFire = true
                        if turret.heat then
                            canFire = turret.heat.current < (turretModule.MAX_HEAT or 10)
                        end
                        
                        if canFire then
                            -- Calculate laser start position
                            local laserStartX = pos.x + math.cos(fireAngle) * muzzleDistance
                            local laserStartY = pos.y + math.sin(fireAngle) * muzzleDistance
                            local collider = ECS.getComponent(eid, "Collidable")
                            if collider and dist > 0 then
                                laserStartX = pos.x + (dy / dist) * (collider.radius + muzzleDistance)
                                laserStartY = pos.y + (dy / dist) * (collider.radius + muzzleDistance)
                            end
                            
                            -- Apply damage and get collision result
                            local beamResult = turretModule.applyBeam(eid, laserStartX, laserStartY, playerPos.x, playerPos.y, dt, turret)
                            
                            -- Update laser beam visual endpoint based on collision
                            if turret.laserEntity then
                                local laserBeam = ECS.getComponent(turret.laserEntity, "LaserBeam")
                                if laserBeam then
                                    laserBeam.start = {x = laserStartX, y = laserStartY}
                                    -- Use collision point if hit, otherwise use target position
                                    if beamResult and beamResult.hit and beamResult.intersection then
                                        laserBeam.endPos = {x = beamResult.intersection.x, y = beamResult.intersection.y}
                                    else
                                        laserBeam.endPos = {x = playerPos.x, y = playerPos.y}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        elseif ai.state == "orbit" and playerPos then
            -- Orbit player at optimal turret range
            local dx = playerPos.x - pos.x
            local dy = playerPos.y - pos.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 0 then
                -- Calculate optimal orbit distance (within full damage range for lasers, or 80% of range for projectiles)
                local turretModule = nil
                if turret and turret.moduleName then
                    local TurretSystem = ECS.getSystem("TurretSystem")
                    if TurretSystem and TurretSystem.turretModules then
                        turretModule = TurretSystem.turretModules[turret.moduleName]
                    end
                end

                local optimalDistance
                if turretModule and turretModule.CONTINUOUS then
                    -- For continuous weapons (lasers), orbit within full damage range
                    optimalDistance = 300  -- Well within 400 unit full damage range
                else
                    -- For projectile weapons, use 80% of engagement range
                    optimalDistance = engagementRange * 0.8
                end
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
                
                local ForceUtils = require('src.systems.force_utils')
                local physics = ECS.getComponent(eid, "Physics")
                
                if distanceError > 0 then
                    -- Too far - move closer (thrust-based)
                    local desiredVx = orbitX - correctionX
                    local desiredVy = orbitY - correctionY
                    if physics then
                        local thrustX = (desiredVx - vel.vx) * STEERING * physics.mass
                        local thrustY = (desiredVy - vel.vy) * STEERING * physics.mass
                        ForceUtils.applyForce(eid, thrustX, thrustY)
                    end
                else
                    -- Too close - move away (thrust-based)
                    local desiredVx = orbitX + correctionX
                    local desiredVy = orbitY + correctionY
                    if physics then
                        local thrustX = (desiredVx - vel.vx) * STEERING * physics.mass
                        local thrustY = (desiredVy - vel.vy) * STEERING * physics.mass
                        ForceUtils.applyForce(eid, thrustX, thrustY)
                    end
                end
                
                -- Fire turret at player while orbiting (if line of sight is clear)
                local hasLineOfSight = true
                if ENABLE_LINE_OF_SIGHT then
                    local los_ok, los_result = pcall(function()
                        return getLineOfSight().canSeeTarget(pos.x, pos.y, playerPos.x, playerPos.y, eid)
                    end)
                    if los_ok then
                        hasLineOfSight = los_result
                    end
                end
                
                if hasLineOfSight and turret and turret.moduleName and dist < engagementRange then
                    -- Store turret aim position for rendering
                    local dx = playerPos.x - pos.x
                    local dy = playerPos.y - pos.y
                    local fireAngle = math.atan2(dy, dx)
                    local muzzleDistance = 12
                    turret.aimX = pos.x + math.cos(fireAngle) * muzzleDistance
                    turret.aimY = pos.y + math.sin(fireAngle) * muzzleDistance

                    local TurretSystem = ECS.getSystem("TurretSystem")
                    if TurretSystem and TurretSystem.fireTurret then
                        -- Always call fireTurret - it handles heat checks and laser entity management
                        -- This ensures laser entity gets recreated after cooldown completes
                        TurretSystem.fireTurret(eid, playerPos.x, playerPos.y, dt)
                        
                        -- For continuous weapons (lasers), apply beam damage if not overheating
                        local turretModule = TurretSystem.turretModules[turret.moduleName]
                        if turretModule and turretModule.CONTINUOUS and turretModule.applyBeam then
                            -- Check if laser can fire (not overheated)
                            local canFire = true
                            if turret.heat then
                                canFire = turret.heat.current < (turretModule.MAX_HEAT or 10)
                            end
                            
                            if canFire then
                                -- Calculate laser start position
                                local laserStartX = pos.x + math.cos(fireAngle) * muzzleDistance
                                local laserStartY = pos.y + math.sin(fireAngle) * muzzleDistance
                                local collider = ECS.getComponent(eid, "Collidable")
                                if collider and dist > 0 then
                                    laserStartX = pos.x + (dy / dist) * (collider.radius + muzzleDistance)
                                    laserStartY = pos.y + (dy / dist) * (collider.radius + muzzleDistance)
                                end
                                
                                -- Apply damage and get collision result
                                local beamResult = turretModule.applyBeam(eid, laserStartX, laserStartY, playerPos.x, playerPos.y, dt, turret)
                                
                                -- Update laser beam visual endpoint based on collision
                                if turret.laserEntity then
                                    local laserBeam = ECS.getComponent(turret.laserEntity, "LaserBeam")
                                    if laserBeam then
                                        laserBeam.start = {x = laserStartX, y = laserStartY}
                                        -- Use collision point if hit, otherwise use target position
                                        if beamResult and beamResult.hit and beamResult.intersection then
                                            laserBeam.endPos = {x = beamResult.intersection.x, y = beamResult.intersection.y}
                                        else
                                            laserBeam.endPos = {x = playerPos.x, y = playerPos.y}
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end
end

return AI
