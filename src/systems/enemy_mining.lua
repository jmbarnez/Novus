---@diagnostic disable: undefined-global
-- Enemy Mining System - Allows AI-controlled miners to harvest asteroids slowly
-- Miners mine asteroids with their own laser beams, not the player

local ECS = require('src.ecs')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')

local EnemyMiningSystem = {
    name = "EnemyMiningSystem",
    priority = 8  -- Run before destruction system
}

-- Enemy miner DPS - significantly lower than player mining lasers (player = 50 DPS)
local ENEMY_MINER_DPS = 0.8  -- 1.6% of player damage (10x less than before)

-- Range to detect and mine asteroids
local MINING_DETECTION_RANGE = 800 -- Increased so miners always find asteroids, never players

-- Track laser beams per miner (key: minerId, value: laserEntity)
local minerLasers = {}

function EnemyMiningSystem.update(dt)
    -- Clean up laser beams for destroyed miners
    for minerId, laserEntityId in pairs(minerLasers) do
        -- Check if the miner still exists
        local minerPos = ECS.getComponent(minerId, "Position")
        if not minerPos then
            -- Miner is destroyed, clean up its laser beam
            local laserBeam = ECS.getComponent(laserEntityId, "LaserBeam")
            if laserBeam then
                ECS.destroyEntity(laserEntityId)
            end
            minerLasers[minerId] = nil
        end
    end
    
    -- Find all mining AI ships
    local minerEntities = ECS.getEntitiesWith({"AI", "Position", "Velocity", "Turret"})
    
    for _, minerId in ipairs(minerEntities) do
        local turret = ECS.getComponent(minerId, "Turret")
        local ai = ECS.getComponent(minerId, "AI")
        
        -- Process only mining AI entities
        if ai and ai.type == "mining" then
            -- ALWAYS force mining state
            ai.state = "mining"
            
            local pos = ECS.getComponent(minerId, "Position")
            local vel = ECS.getComponent(minerId, "Velocity")
            if not (pos and vel) then goto continue end
            
            -- Get ship design for thrustForce
            local wreckage = ECS.getComponent(minerId, "Wreckage")
            local ShipLoader = require('src.ship_loader')
            local design = wreckage and ShipLoader.getDesign(wreckage.sourceShip)
            local thrustForce = design and design.thrustForce or 100
            
            -- Find closest asteroid within range
            local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Durability"})
            local closestAsteroid = nil
            local closestDistSq = MINING_DETECTION_RANGE * MINING_DETECTION_RANGE
            
            -- Extra: Function to verify a valid asteroid target (defensive, in case of future entity confusion)
            local function isAsteroidEntity(entId)
                return ECS.hasComponent(entId, "Asteroid")
            end
            
            for _, asteroidId in ipairs(asteroids) do
                local asteroidPos = ECS.getComponent(asteroidId, "Position")
                if asteroidPos then
                    local dx = asteroidPos.x - pos.x
                    local dy = asteroidPos.y - pos.y
                    local distSq = dx * dx + dy * dy
                    if distSq < closestDistSq then
                        closestDistSq = distSq
                        closestAsteroid = asteroidId
                    end
                end
            end

            -- Miners ONLY target asteroids, never players (defensive double-check)
            -- Check for a valid asteroid target FIRST and clean up any beam proactively (before doing any targeting work)
            if not (closestAsteroid and isAsteroidEntity(closestAsteroid)) then
                EnemyMiningSystem.destroyMinerLaser(minerId)
                goto continue
            end

            -- If here, we have a valid asteroid. All beam logic is safe now.
            local asteroidPos = ECS.getComponent(closestAsteroid, "Position")
            if asteroidPos then
                -- Move toward asteroid to stay in mining range (orbit behavior)
                local dx = asteroidPos.x - pos.x
                local dy = asteroidPos.y - pos.y
                local distToAsteroid = math.sqrt(dx * dx + dy * dy)
                local targetDistance = 150
                local ForceUtils = require('src.systems.force_utils')
                local physics = ECS.getComponent(minerId, "Physics")
                if distToAsteroid > targetDistance then
                    if distToAsteroid > 0 and physics then
                        local desiredVx = (dx / distToAsteroid) * thrustForce * 0.5
                        local desiredVy = (dy / distToAsteroid) * thrustForce * 0.5
                        local thrustX = (desiredVx - vel.vx) * 0.6 * physics.mass
                        local thrustY = (desiredVy - vel.vy) * 0.6 * physics.mass
                        ForceUtils.applyForce(minerId, thrustX, thrustY)
                    end
                else
                    if physics then
                        local time = love.timer.getTime()
                        local orbitAngle = time * 2
                        local desiredVx = math.cos(orbitAngle) * thrustForce * 0.15
                        local desiredVy = math.sin(orbitAngle) * thrustForce * 0.15
                        local thrustX = (desiredVx - vel.vx) * 0.6 * physics.mass
                        local thrustY = (desiredVy - vel.vy) * 0.6 * physics.mass
                        ForceUtils.applyForce(minerId, thrustX, thrustY)
                    end
                end
                EnemyMiningSystem.updateMinerLaser(minerId, pos.x, pos.y, asteroidPos.x, asteroidPos.y)
                EnemyMiningSystem.applyMinerDamage(minerId, closestAsteroid, asteroidPos.x, asteroidPos.y, dt)
                -- Update turret aim for rendering
                local turret = ECS.getComponent(minerId, "Turret")
                if turret then
                    local fireAngle = math.atan2(dy, dx)
                    local muzzleDistance = 12
                    turret.aimX = pos.x + math.cos(fireAngle) * muzzleDistance
                    turret.aimY = pos.y + math.sin(fireAngle) * muzzleDistance
                end
            end
        end
        
        ::continue::
    end
end

-- Create or update laser beam for a miner (independent from turret module)
function EnemyMiningSystem.updateMinerLaser(minerId, startX, startY, endX, endY)
    -- Destroy old laser if it exists
    if minerLasers[minerId] then
        local oldLaser = ECS.getComponent(minerLasers[minerId], "LaserBeam")
        if oldLaser then
            ECS.destroyEntity(minerLasers[minerId])
        end
    end
    
    -- Offset start position away from owner ship
    local offsetStartX = startX
    local offsetStartY = startY
    local ownerCollidable = ECS.getComponent(minerId, "Collidable")
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
        color = {1, 1, 0, 1}  -- Yellow for mining laser
    })
    
    minerLasers[minerId] = laserEntity
end

-- Apply mining damage to asteroid
function EnemyMiningSystem.applyMinerDamage(minerId, asteroidId, asteroidX, asteroidY, dt)
    local minerPos = ECS.getComponent(minerId, "Position")
    if not minerPos then return end
    
    -- Check line-of-sight to asteroid
    local intersection = CollisionSystem.linePolygonIntersect(minerPos.x, minerPos.y, asteroidX, asteroidY, asteroidId)
    
    if intersection then
        -- Update laser visual to end at collision point instead of asteroid center
        local laserEntity = minerLasers[minerId]
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
            ECS.addComponent(asteroidId, "LastDamager", {pilotId = minerId, weaponType = "enemy_mining_laser"})
        end
        
        -- Create debris at impact point
        local renderable = ECS.getComponent(asteroidId, "Renderable")
        local color = renderable and renderable.color or {0.6, 0.4, 0.2, 1}
        DebrisSystem.createDebris(intersection.x, intersection.y, 1, color)
    end
end

-- Destroy laser beam for a miner
function EnemyMiningSystem.destroyMinerLaser(minerId)
    if minerLasers[minerId] then
        local laserBeam = ECS.getComponent(minerLasers[minerId], "LaserBeam")
        if laserBeam then
            ECS.destroyEntity(minerLasers[minerId])
        end
        minerLasers[minerId] = nil
    end
end

return EnemyMiningSystem


