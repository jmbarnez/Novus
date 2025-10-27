-- AI Behavior Modules - Reusable, composable behavior implementations
-- Each behavior module handles one specific AI behavior (patrol, chase, orbit)
-- This makes it easy to add new behaviors without modifying core system

local ECS = require('src.ecs')
local ForceUtils = require('src.systems.force_utils')
local AiTurretHelper = require('src.systems.ai_turret_helper')
local TurretRegistry = require('src.turret_registry')

-- Lazy-load TurretSystem to avoid circular dependencies
local TurretSystem

local function getTurretSystem()
    if not TurretSystem then
        TurretSystem = require('src.systems.turret')
    end
    return TurretSystem
end

local Behaviors = {}
local AIStateManager = require('src.systems.ai_state_manager')

-- ============================================================================
-- BEHAVIOR UTILITIES - Common code shared across behaviors
-- ============================================================================

-- Apply steering-aware thrust that respects current velocity and rotation
local function applySteeringAwareThrust(eid, desiredDirX, desiredDirY, thrustMagnitude, steeringResponsiveness, physics, targetSpeed)
    local success, result = pcall(function()
        local vel = ECS.getComponent(eid, "Velocity")
        local polygonShape = ECS.getComponent(eid, "PolygonShape")
        local angularVel = ECS.getComponent(eid, "AngularVelocity")
        local rotMass = ECS.getComponent(eid, "RotationalMass")
        if not vel or not physics then
            return
        end

        local responsiveness = steeringResponsiveness or 0.3

        -- Normalize desired direction
        local desiredMagnitude = math.sqrt(desiredDirX * desiredDirX + desiredDirY * desiredDirY)
        if desiredMagnitude > 0 then
            desiredDirX = desiredDirX / desiredMagnitude
            desiredDirY = desiredDirY / desiredMagnitude
        end

        -- If we have velocity, blend new direction with current direction (for steering smoothness)
        local currentSpeed = math.sqrt(vel.vx * vel.vx + vel.vy * vel.vy)
        local finalDirX = desiredDirX
        local finalDirY = desiredDirY
        if currentSpeed > 0.1 then
            local currentDirX = vel.vx / currentSpeed
            local currentDirY = vel.vy / currentSpeed
            finalDirX = (desiredDirX * responsiveness + currentDirX * (1 - responsiveness))
            finalDirY = (desiredDirY * responsiveness + currentDirY * (1 - responsiveness))
            local finalMagnitude = math.sqrt(finalDirX * finalDirX + finalDirY * finalDirY)
            if finalMagnitude > 0 then
                finalDirX = finalDirX / finalMagnitude
                finalDirY = finalDirY / finalMagnitude
            end
        end

        -- Velocity-matching controller: try to match velocity vector to target direction and speed
        targetSpeed = targetSpeed or 99999
        local desiredVx = finalDirX * targetSpeed
        local desiredVy = finalDirY * targetSpeed
        local errorVx = desiredVx - vel.vx
        local errorVy = desiredVy - vel.vy
        local kP = 1.0
        local forceX = kP * errorVx * physics.mass
        local forceY = kP * errorVy * physics.mass
        -- Clamp force magnitude to available thrustMagnitude
        local forceMag = math.sqrt(forceX * forceX + forceY * forceY)
        if forceMag > thrustMagnitude then
            local scale = thrustMagnitude / forceMag
            forceX = forceX * scale
            forceY = forceY * scale
        end
        ForceUtils.applyForce(eid, forceX, forceY)

        -- Apply rotational steering if the entity can rotate
        if polygonShape and angularVel and rotMass then
        local desiredAngle = math.atan2(finalDirY, finalDirX)
            local currentAngle = polygonShape.rotation or 0

            -- Normalize angles to [-pi, pi]
            local angleDiff = desiredAngle - currentAngle
            while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
            while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end

            -- Apply torque to turn towards desired angle
            local turnResponsiveness = responsiveness * 2  -- Adjust as needed
            local torque = angleDiff * turnResponsiveness * rotMass.inertia
            ForceUtils.applyTorque(eid, torque)
        end
    end)

    if not success then
        AIStateManager.setError(eid, "PHYSICS_ERROR", "applySteeringAwareThrust failed: " .. tostring(result))
    end
end

-- Fire at target if in range
local function fireAtTarget(eid, turret, pos, playerPos, dt)
    local success, result = pcall(function()
        if not (turret and turret.moduleName and playerPos) then
            return
        end

        local turretSys = getTurretSystem()
        if not (turretSys and turretSys.fireTurret) then
            return
        end

        local dx = playerPos.x - pos.x
        local dy = playerPos.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)

        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule and turretModule.ZERO_DAMAGE_RANGE then
            if dist > turretModule.ZERO_DAMAGE_RANGE then
                return
            end
        end

        AiTurretHelper.aimTurretAtTarget(eid, turret, pos, playerPos)
        turretSys.fireTurret(eid, playerPos.x, playerPos.y, dt)

        if turretModule and turretModule.CONTINUOUS and turretModule.applyBeam then
            AiTurretHelper.fireLaserAtTarget(eid, turret, turretModule, playerPos, dt)
        end
    end)

    if not success then
        AIStateManager.setError(eid, "BEHAVIOR_ERROR", "fireAtTarget failed: " .. tostring(result))
    end
end

local function distSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx*dx + dy*dy
end

-- ============================================================================
-- PATROL BEHAVIOR
-- ============================================================================

Behaviors.Patrol = {}

function Behaviors.Patrol.update(eid, ai, pos, vel, turret, design, dt)
    local success, result = pcall(function()
        local thrustForce = design.thrustForce or 0
        if thrustForce == 0 then return end

        if #ai.patrolPoints > 0 then
            local target = ai.patrolPoints[ai.currentPoint]
            if not target then return end

            local dx = target.x - pos.x
            local dy = target.y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < 10 then
                ai.currentPoint = ai.currentPoint % #ai.patrolPoints + 1
            else
                local dx_norm = dx / dist
                local dy_norm = dy / dist
                local physics = ECS.getComponent(eid, "Physics")
                local targetSpeed = design.patrolSpeed or 60
                applySteeringAwareThrust(eid, dx_norm, dy_norm, thrustForce, design.steeringResponsiveness, physics, targetSpeed)
            end
        else
            -- NO VALID PATROL POINTS: gentle wandering near spawn
            local wanderRadius = design.wanderRadius or 150
            local thrustScale = design.wanderThrustMultiplier or 0.3

            local dx = pos.x - (ai.spawnX or pos.x)
            local dy = pos.y - (ai.spawnY or pos.y)
            local distsq = dx*dx + dy*dy

            if distsq > wanderRadius * wanderRadius then
                local dist = math.sqrt(distsq)
                local desiredDirX = -dx / dist
                local desiredDirY = -dy / dist
                local physics = ECS.getComponent(eid, "Physics")
                local targetSpeed = design.patrolSpeed or 60
                applySteeringAwareThrust(eid, desiredDirX, desiredDirY, thrustForce, design.steeringResponsiveness, physics, targetSpeed)
            else
                ai._wanderTimer = (ai._wanderTimer or 0) - dt
                if not ai._wanderAngle or ai._wanderTimer <= 0 then
                    ai._wanderAngle = math.random() * 2 * math.pi
                    ai._wanderTimer = 4 + math.random() * 6
                end
                local desiredDirX = math.cos(ai._wanderAngle)
                local desiredDirY = math.sin(ai._wanderAngle)
                local physics = ECS.getComponent(eid, "Physics")
                local targetSpeed = (design.patrolSpeed or 60) * 0.6
                applySteeringAwareThrust(eid, desiredDirX, desiredDirY, thrustScale * thrustForce, design.steeringResponsiveness, physics, targetSpeed)
            end
        end

        -- Idle turret swing
        if turret then
            turret._swingTimer = (turret._swingTimer or 0) - dt
            if not turret._swingAngle or turret._swingTimer <= 0 then
                turret._swingAngle = math.random() * 2 * math.pi
                turret._swingTimer = 1 + math.random() * 2
            end
            local swingRadius = 100
            turret.aimX = pos.x + math.cos(turret._swingAngle) * swingRadius
            turret.aimY = pos.y + math.sin(turret._swingAngle) * swingRadius
        end
    end)

    if not success then
        AIStateManager.setError(eid, "BEHAVIOR_ERROR", "Patrol.update failed: " .. tostring(result))
    end
end

function Behaviors.Patrol.swingTurret(turret, pos, dt)
    if not turret then return end
    turret._swingTimer = (turret._swingTimer or 0) - dt
    if not turret._swingAngle or turret._swingTimer <= 0 then
        turret._swingAngle = math.random() * 2 * math.pi
        turret._swingTimer = 1 + math.random() * 2
    end
    local swingRadius = 100
    turret.aimX = pos.x + math.cos(turret._swingAngle) * swingRadius
    turret.aimY = pos.y + math.sin(turret._swingAngle) * swingRadius
end

-- ============================================================================
-- CHASE BEHAVIOR
-- ============================================================================

Behaviors.Chase = {}

function Behaviors.Chase.update(eid, ai, pos, vel, turret, design, playerPos, dt)
    local success, result = pcall(function()
        local thrustForce = design.thrustForce or 0
        if thrustForce == 0 or not playerPos then return end

        local moveDx = playerPos.x - pos.x
        local moveDy = playerPos.y - pos.y
        local moveDist = math.sqrt(moveDx*moveDx + moveDy*moveDy)

        if moveDist > 0 then
            local dx_norm = moveDx / moveDist
            local dy_norm = moveDy / moveDist
            local physics = ECS.getComponent(eid, "Physics")
            local base = design.patrolSpeed or 60
            local targetSpeed = math.max(base * 2, 120)
            applySteeringAwareThrust(eid, dx_norm, dy_norm, thrustForce, design.steeringResponsiveness, physics, targetSpeed)
        end

        if turret and playerPos then
        AiTurretHelper.aimTurretAtTarget(eid, turret, pos, playerPos)
        end

        if turret and turret.moduleName then
            fireAtTarget(eid, turret, pos, playerPos, dt)
        end
    end)

    if not success then
        AIStateManager.setError(eid, "BEHAVIOR_ERROR", "Chase.update failed: " .. tostring(result))
    end
end

-- ============================================================================
-- ORBIT BEHAVIOR
-- ============================================================================

Behaviors.Orbit = {}

function Behaviors.Orbit.update(eid, ai, pos, vel, turret, design, playerPos, dt)
    local success, result = pcall(function()
        local thrustForce = design.thrustForce or 0
        if thrustForce == 0 or not playerPos then return end

        -- Calculate orbit parameters
        local orbitRadius = design.orbitRadius or 200
        local orbitSpeed = design.orbitSpeed or 1.0  -- Radians per second

        -- Initialize orbit direction if not set
        if not ai.orbitDirection then
            ai.orbitDirection = 1  -- 1 for clockwise, -1 for counter-clockwise
        end

        -- Calculate target position on orbit circle
        local dx = pos.x - playerPos.x
        local dy = pos.y - playerPos.y
        local distance = math.sqrt(dx*dx + dy*dy)

        -- Desired orbit position (perpendicular to current vector)
        local orbitX, orbitY
        if distance > 0 then
            -- Normalize direction vector
            local dirX = dx / distance
            local dirY = dy / distance

            -- Rotate 90 degrees for orbit (clockwise or counter-clockwise)
            if ai.orbitDirection > 0 then
                orbitX = dirX * math.cos(math.pi/2) - dirY * math.sin(math.pi/2)
                orbitY = dirX * math.sin(math.pi/2) + dirY * math.cos(math.pi/2)
            else
                orbitX = dirX * math.cos(-math.pi/2) - dirY * math.sin(-math.pi/2)
                orbitY = dirX * math.sin(-math.pi/2) + dirY * math.cos(-math.pi/2)
            end

            -- Scale to orbit radius
            orbitX = orbitX * orbitRadius
            orbitY = orbitY * orbitRadius

            -- Offset from player position
            orbitX = orbitX + playerPos.x
            orbitY = orbitY + playerPos.y
        else
            -- Fallback if exactly at player position
            orbitX = pos.x + orbitRadius
            orbitY = pos.y
        end

        -- Calculate thrust direction towards orbit point
        local thrustDirX = orbitX - pos.x
        local thrustDirY = orbitY - pos.y
        local thrustDist = math.sqrt(thrustDirX*thrustDirX + thrustDirY*thrustDirY)

        if thrustDist > 0 then
            -- Normalize thrust direction
            thrustDirX = thrustDirX / thrustDist
            thrustDirY = thrustDirY / thrustDist

            -- Add tangential velocity for orbital motion
            local tangentX = -thrustDirY * ai.orbitDirection
            local tangentY = thrustDirX * ai.orbitDirection

            -- Blend radial and tangential thrust
            local radialWeight = 0.7
            local tangentWeight = 0.3
            thrustDirX = thrustDirX * radialWeight + tangentX * tangentWeight
            thrustDirY = thrustDirY * radialWeight + tangentY * tangentWeight

            -- Renormalize
            local finalDist = math.sqrt(thrustDirX*thrustDirX + thrustDirY*thrustDirY)
            if finalDist > 0 then
                thrustDirX = thrustDirX / finalDist
                thrustDirY = thrustDirY / finalDist
            end

            local physics = ECS.getComponent(eid, "Physics")
            local orbitTargetSpeed = (design.patrolSpeed or 60) * 0.9
            applySteeringAwareThrust(eid, thrustDirX, thrustDirY, thrustForce, design.steeringResponsiveness, physics, orbitTargetSpeed)
        end

        if turret and playerPos then
            AiTurretHelper.aimTurretAtTarget(eid, turret, pos, playerPos)
        end

        if turret and turret.moduleName then
            fireAtTarget(eid, turret, pos, playerPos, dt)
        end
    end)

    if not success then
        AIStateManager.setError(eid, "BEHAVIOR_ERROR", "Orbit.update failed: " .. tostring(result))
    end
end

-- ============================================================================
-- AGGRESSIVE BEHAVIOR - Reacts to being attacked by pursuing attacker
-- ============================================================================

Behaviors.Aggressive = {}

function Behaviors.Aggressive.update(eid, ai, pos, vel, turret, design, playerPos, dt)
    local success, result = pcall(function()
        local thrustForce = design.thrustForce or 0
        if thrustForce == 0 then return end

        -- Find the attacker's position
        local targetPos = nil
        if ai.lastAttacker then
            local attackerPos = ECS.getComponent(ai.lastAttacker, "Position")
            if attackerPos then
                targetPos = attackerPos
            end
        end

        -- If no attacker found, use player position as fallback
        if not targetPos and playerPos then
            targetPos = playerPos
        end

        if not targetPos then return end

        -- Move directly toward the attacker at high speed
        local moveDx = targetPos.x - pos.x
        local moveDy = targetPos.y - pos.y
        local moveDist = math.sqrt(moveDx*moveDx + moveDy*moveDy)

        if moveDist > 0 then
            local dx_norm = moveDx / moveDist
            local dy_norm = moveDy / moveDist
            local physics = ECS.getComponent(eid, "Physics")
            local base = design.patrolSpeed or 60
            -- Move faster when aggressive
            local targetSpeed = math.max(base * 2.5, 150)
            applySteeringAwareThrust(eid, dx_norm, dy_norm, thrustForce, design.steeringResponsiveness, physics, targetSpeed)
        end

        -- Aim and fire at the target
        if turret and targetPos then
            AiTurretHelper.aimTurretAtTarget(eid, turret, pos, targetPos)
        end

        if turret and turret.moduleName then
            fireAtTarget(eid, turret, pos, targetPos, dt)
        end
    end)

    if not success then
        AIStateManager.setError(eid, "BEHAVIOR_ERROR", "Aggressive.update failed: " .. tostring(result))
    end
end

return Behaviors
