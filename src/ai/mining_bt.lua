-- Mining AI Behavior Tree definition
local BehaviorTree = require('src.ai.behavior_tree')
local ECS = require('src.ecs')
local ShipLoader = require('src.ship_loader')
local Behaviors = require('src.systems.ai_behaviors')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local EnergySystem = require('src.systems.energy')

local SAFE_FLEE_DISTANCE = 900
local LOST_ATTACKER_GRACE = 1.5

-- Mining constants (migrated from enemy_mining.lua)
local ENEMY_MINER_DPS = 0.8
local MINING_DETECTION_RANGE = 800
local MINING_RANGE = 150

-- Track laser beams per miner (key: minerId, value: laserEntity)
local minerLasers = {}

local function buildDesignData(entity)
    local physics = ECS.getComponent(entity, "Physics")
    local wreck = ECS.getComponent(entity, "Wreckage")
    local baseDesign = nil
    if wreck and wreck.sourceShip then
        baseDesign = ShipLoader.getDesign(wreck.sourceShip)
    end

    local thrust = (baseDesign and baseDesign.thrustForce)
        or (physics and physics.thrustForce)
        or 150
    local patrolSpeed = (baseDesign and baseDesign.patrolSpeed)
        or (physics and physics.maxSpeed and physics.maxSpeed * 0.4)
        or 120
    local steering = (baseDesign and baseDesign.steeringResponsiveness) or 0.3

    return {
        thrustForce = thrust,
        patrolSpeed = patrolSpeed,
        steeringResponsiveness = steering
    }
end

local function resolveDamageSource(entity, ai)
    local candidates = {}
    if ai and ai.lastAttacker then
        table.insert(candidates, ai.lastAttacker)
    end
    local lastDamager = ECS.getComponent(entity, "LastDamager")
    if lastDamager and lastDamager.pilotId then
        table.insert(candidates, lastDamager.pilotId)
    end
    if ai and ai._fleeState and ai._fleeState.attackerId then
        table.insert(candidates, ai._fleeState.attackerId)
    end

    local controlledCache = nil

    local function resolve(candidateId)
        if not candidateId then return nil end
        if ECS.getComponent(candidateId, "Position") then
            return candidateId
        end

        local input = ECS.getComponent(candidateId, "InputControlled")
        if input and input.targetEntity and ECS.getComponent(input.targetEntity, "Position") then
            return input.targetEntity
        end

        controlledCache = controlledCache or ECS.getEntitiesWith({"ControlledBy", "Position"})
        for _, entityId in ipairs(controlledCache) do
            local controlledBy = ECS.getComponent(entityId, "ControlledBy")
            if controlledBy and controlledBy.pilotId == candidateId then
                return entityId
            end
        end
        return nil
    end

    for _, candidate in ipairs(candidates) do
        local resolved = resolve(candidate)
        if resolved then
            return resolved
        end
    end

    return nil
end

local function fleeFromAttacker(entity, dt)
    local ai = ECS.getComponent(entity, "AI")
    if not ai then return BehaviorTree.FAILURE end

    if ai.aggressiveTimer and ai.aggressiveTimer > 0 then
        ai.aggressiveTimer = math.max(0, ai.aggressiveTimer - dt)
    end

    ai._fleeState = ai._fleeState or { active = false, attackerId = nil, lostTimer = 0 }
    local fleeState = ai._fleeState
    local wasActive = fleeState.active

    local attackerEntity = resolveDamageSource(entity, ai)
    if attackerEntity then
        fleeState.attackerId = attackerEntity
        fleeState.active = true
        fleeState.lostTimer = LOST_ATTACKER_GRACE
        if not wasActive then
            ECS.removeComponent(entity, "MiningTarget")
        end
    elseif fleeState.active then
        fleeState.lostTimer = (fleeState.lostTimer or 0) - dt
        if fleeState.lostTimer <= 0 then
            fleeState.active = false
            fleeState.attackerId = nil
            ai.lastAttacker = nil
            ai.aggressiveTimer = 0
            ai.state = "mining"
            ECS.removeComponent(entity, "LastDamager")
            ECS.removeComponent(entity, "MiningTarget")
        end
    end

    if not fleeState.active then
        return BehaviorTree.FAILURE
    end

    ai.state = "fleeing"

    local pos = ECS.getComponent(entity, "Position")
    local vel = ECS.getComponent(entity, "Velocity")
    if not (pos and vel) then return BehaviorTree.FAILURE end

    local attackerPos = ECS.getComponent(fleeState.attackerId, "Position")
    if not attackerPos then
        return BehaviorTree.RUNNING
    end

    local dx = pos.x - attackerPos.x
    local dy = pos.y - attackerPos.y
    local distSq = dx*dx + dy*dy

    if distSq >= SAFE_FLEE_DISTANCE * SAFE_FLEE_DISTANCE then
        fleeState.active = false
        fleeState.attackerId = nil
        fleeState.lostTimer = 0
        ai.lastAttacker = nil
        ai.aggressiveTimer = 0
        ai.state = "mining"
        ECS.removeComponent(entity, "MiningTarget")
        ECS.removeComponent(entity, "LastDamager")
        return BehaviorTree.FAILURE
    end

    local dist = math.sqrt(distSq)
    if dist < 1 then
        dx, dy = SAFE_FLEE_DISTANCE, 0
        dist = SAFE_FLEE_DISTANCE
    end

    local fleeTarget = {
        x = pos.x + (dx / dist) * SAFE_FLEE_DISTANCE,
        y = pos.y + (dy / dist) * SAFE_FLEE_DISTANCE
    }

    local designData = buildDesignData(entity)
    Behaviors.Chase.update(entity, ai, pos, vel, nil, designData, fleeTarget, dt)

    return BehaviorTree.RUNNING
end

-- Blackboard: store target asteroid as a component
local function findAsteroid(entity, dt)
    local pos = ECS.getComponent(entity, "Position")
    if not pos then return BehaviorTree.FAILURE end
    -- Respect mining detection radius where possible to avoid huge cross-map mining runs
    local aiComp = ECS.getComponent(entity, "AI")
    local detectionRadius = aiComp and aiComp.detectionRadius or MINING_DETECTION_RANGE
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Durability"})
    local closest, closestDistSq = nil, math.huge
    for _, aid in ipairs(asteroids) do
        local apos = ECS.getComponent(aid, "Position")
        if apos then
            local dx, dy = apos.x - pos.x, apos.y - pos.y
            local distSq = dx*dx + dy*dy
            if distSq > detectionRadius * detectionRadius then
                -- Skip asteroids beyond detection range
            else
                if distSq < closestDistSq then
                    closest, closestDistSq = aid, distSq
                end
            end
        end
    end
    if closest then
        ECS.addComponent(entity, "MiningTarget", { asteroid = closest })
        return BehaviorTree.SUCCESS
    else
        ECS.removeComponent(entity, "MiningTarget")
        return BehaviorTree.FAILURE
    end
end

local function moveToAsteroid(entity, dt)
    local pos = ECS.getComponent(entity, "Position")
    local vel = ECS.getComponent(entity, "Velocity")
    local miningTarget = ECS.getComponent(entity, "MiningTarget")
    if not (pos and vel and miningTarget and miningTarget.asteroid) then return BehaviorTree.FAILURE end
    local asteroidPos = ECS.getComponent(miningTarget.asteroid, "Position")
    if not asteroidPos then return BehaviorTree.FAILURE end
    local dx, dy = asteroidPos.x - pos.x, asteroidPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist <= MINING_RANGE then
        return BehaviorTree.SUCCESS
    end

    -- Use steering-aware chase to approach asteroid (prevents instant direction changes)
    local aiComp = ECS.getComponent(entity, "AI")
    local turret = ECS.getComponent(entity, "Turret")
    local wreck = ECS.getComponent(entity, "Wreckage")
    local design = wreck and ShipLoader.getDesign(wreck.sourceShip)

    Behaviors.Chase.update(entity, aiComp or {}, pos, vel, turret, design or {}, asteroidPos, dt)
    return BehaviorTree.RUNNING
end

-- Helper: Update laser beam for miner
local function updateMinerLaser(entity, startX, startY, endX, endY)
    -- Destroy old laser if it exists
    if minerLasers[entity] then
        local oldLaser = ECS.getComponent(minerLasers[entity], "LaserBeam")
        if oldLaser then
            ECS.destroyEntity(minerLasers[entity])
        end
    end

    -- Offset start position away from owner ship
    local offsetStartX = startX
    local offsetStartY = startY
    local ownerCollidable = ECS.getComponent(entity, "Collidable")
    if ownerCollidable then
        local dx = endX - startX
        local dy = endY - startY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            offsetStartX = startX + (dx / dist) * (ownerCollidable.radius + 5)
            offsetStartY = startY + (dy / dist) * (ownerCollidable.radius + 5)
        end
    end

    -- Create new laser beam entity
    local laserEntity = ECS.createEntity()
    ECS.addComponent(laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = endX, y = endY},
        color = {0, 0.7, 1, 1}  -- Blue for mining laser (matches continuous beam)
    })

    minerLasers[entity] = laserEntity
end

-- Helper: Apply mining damage
local function applyMinerDamage(entity, asteroidId, asteroidX, asteroidY, dt)
    local minerPos = ECS.getComponent(entity, "Position")
    if not minerPos then return end

    -- Check line-of-sight to asteroid
    local intersection = CollisionSystem.linePolygonIntersect(minerPos.x, minerPos.y, asteroidX, asteroidY, asteroidId)

    if intersection then
        -- Update laser visual to end at collision point instead of asteroid center
        local laserEntity = minerLasers[entity]
        if laserEntity then
            local laserBeam = ECS.getComponent(laserEntity, "LaserBeam")
            if laserBeam then
                laserBeam.endPos = {x = intersection.x, y = intersection.y}
            end
        end

        -- Apply damage
        local durability = ECS.getComponent(asteroidId, "Durability")
        if durability then
            local damageApplied = math.min(ENEMY_MINER_DPS * dt, durability.current)
            durability.current = durability.current - damageApplied

            -- Track that this asteroid is being damaged by an enemy miner
            ECS.addComponent(asteroidId, "LastDamager", {pilotId = entity, weaponType = "enemy_mining_laser"})
        end

        -- Create debris at impact point
        local renderable = ECS.getComponent(asteroidId, "Renderable")
        local color = renderable and renderable.color or {0.6, 0.4, 0.2, 1}
        DebrisSystem.createDebris(intersection.x, intersection.y, 1, color)
    end
end

-- Helper: Handle orbital positioning around asteroid
local function maintainMiningPosition(entity, dt)
    local pos = ECS.getComponent(entity, "Position")
    local vel = ECS.getComponent(entity, "Velocity")
    local miningTarget = ECS.getComponent(entity, "MiningTarget")

    if not (pos and vel and miningTarget and miningTarget.asteroid) then return end

    local asteroidPos = ECS.getComponent(miningTarget.asteroid, "Position")
    if not asteroidPos then return end

    -- Get ship design for thrustForce
    local wreckage = ECS.getComponent(entity, "Wreckage")
    local ShipLoader = require('src.ship_loader')
    local design = wreckage and ShipLoader.getDesign(wreckage.sourceShip)
    local thrustForce = design and design.thrustForce or 100

    -- Move toward asteroid to stay in mining range (orbit behavior)
    local dx = asteroidPos.x - pos.x
    local dy = asteroidPos.y - pos.y
    local distToAsteroid = math.sqrt(dx * dx + dy * dy)

    local ForceUtils = require('src.systems.force_utils')
    local physics = ECS.getComponent(entity, "Physics")

    if distToAsteroid > MINING_RANGE then
        if distToAsteroid > 0 and physics then
            local desiredVx = (dx / distToAsteroid) * thrustForce * 0.5
            local desiredVy = (dy / distToAsteroid) * thrustForce * 0.5
            local thrustX = (desiredVx - vel.vx) * 0.6 * physics.mass
            local thrustY = (desiredVy - vel.vy) * 0.6 * physics.mass
            ForceUtils.applyForce(entity, thrustX, thrustY)
        end
    else
        if physics then
            local time = love.timer.getTime()
            local orbitAngle = time * 2
            local desiredVx = math.cos(orbitAngle) * thrustForce * 0.15
            local desiredVy = math.sin(orbitAngle) * thrustForce * 0.15
            local thrustX = (desiredVx - vel.vx) * 0.6 * physics.mass
            local thrustY = (desiredVy - vel.vy) * 0.6 * physics.mass
            ForceUtils.applyForce(entity, thrustX, thrustY)
        end
    end
end

local function mineAsteroid(entity, dt)
    local miningTarget = ECS.getComponent(entity, "MiningTarget")
    if not (miningTarget and miningTarget.asteroid) then
        -- Clean up laser if no target
        cleanupLaser(entity)
        return BehaviorTree.FAILURE
    end

    local durability = ECS.getComponent(miningTarget.asteroid, "Durability")
    if not durability or durability.current <= 0 then
        ECS.removeComponent(entity, "MiningTarget")
        -- Clean up laser
        cleanupLaser(entity)
        return BehaviorTree.SUCCESS
    end

    -- Check energy requirements (enemy miners have unlimited energy for now)
    -- Future: Add energy consumption logic here if needed
    local energy = ECS.getComponent(entity, "Energy")
    if energy and energy.current < 1 then  -- Minimum energy threshold
        -- Not enough energy to mine, but enemy miners currently have unlimited energy
        -- This is where energy management would go for player-like mining
        return BehaviorTree.RUNNING  -- Keep trying, but don't consume energy yet
    end

    -- Maintain mining position (orbital movement)
    maintainMiningPosition(entity, dt)

    -- Update laser beam and apply damage
    local pos = ECS.getComponent(entity, "Position")
    local asteroidPos = ECS.getComponent(miningTarget.asteroid, "Position")

    if pos and asteroidPos then
        updateMinerLaser(entity, pos.x, pos.y, asteroidPos.x, asteroidPos.y)
        applyMinerDamage(entity, miningTarget.asteroid, asteroidPos.x, asteroidPos.y, dt)

        -- Update turret aim for rendering
        local turret = ECS.getComponent(entity, "Turret")
        if turret then
            local fireAngle = math.atan2(asteroidPos.y - pos.y, asteroidPos.x - pos.x)
            local muzzleDistance = 12
            turret.aimX = pos.x + math.cos(fireAngle) * muzzleDistance
            turret.aimY = pos.y + math.sin(fireAngle) * muzzleDistance
        end
    end

    return BehaviorTree.RUNNING
end

-- Cleanup function for laser beams when miner is destroyed
local function cleanupLaser(entity)
    if minerLasers[entity] then
        local laserBeam = ECS.getComponent(minerLasers[entity], "LaserBeam")
        if laserBeam then
            ECS.destroyEntity(minerLasers[entity])
        end
        minerLasers[entity] = nil
    end
end

-- Build the mining behavior tree
local miningTree = BehaviorTree.selector({
    BehaviorTree.action(fleeFromAttacker),
    BehaviorTree.sequence({
        BehaviorTree.action(findAsteroid),
        BehaviorTree.action(moveToAsteroid),
        BehaviorTree.action(mineAsteroid)
    })
})

-- Export cleanup function for external use
miningTree.cleanupLaser = cleanupLaser

return miningTree
