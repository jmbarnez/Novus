-- Laser Turret Module
-- This module defines the behavior of a standard laser turret.

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local UISystem = require('src.systems.ui')

local MiningLaser = {
    name = "mining_laser",
    LASER_DPS = 50,
    laserEntity = nil  -- Track the current laser beam entity
}

-- Fire the laser - creates and maintains laser beam entity
function MiningLaser.fire(ownerId, startX, startY, endX, endY)
    -- Destroy old laser if it exists
    if MiningLaser.laserEntity then
        local component = ECS.getComponent(MiningLaser.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(MiningLaser.laserEntity)
        end
    end
    
    -- Create new laser beam entity
    MiningLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(MiningLaser.laserEntity, "LaserBeam", {
        start = {x = startX, y = startY},
        endPos = {x = endX, y = endY},
        color = {1, 1, 0, 1}  -- Yellow
    })
    -- Mark this entity as a mining laser projectile for asteroid damage
    ECS.addComponent(MiningLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = MiningLaser.LASER_DPS, brittle = false, isMiningLaser = true})
    -- ...existing code...
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
function MiningLaser.applyBeam(ownerId, startX, startY, endX, endY, dt)
    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitAsteroidId = nil

    -- Check for asteroid hits
    local asteroidHitEntities = ECS.getEntitiesWith({"Asteroid", "Collidable", "Position", "PolygonShape", "Durability"})
    for _, asteroidId in ipairs(asteroidHitEntities) do
        local intersection = CollisionSystem.linePolygonIntersect(startX, startY, endX, endY, asteroidId)
        if intersection then
            local distSq = (intersection.x - startX)^2 + (intersection.y - startY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitAsteroidId = asteroidId
            end
        end
    end

    if closestIntersection and hitAsteroidId then
        -- Apply per-frame DPS to asteroid
        local durability = ECS.getComponent(hitAsteroidId, "Durability")
        if durability then
            local damageApplied = math.min(MiningLaser.LASER_DPS * dt, durability.current)
            durability.current = durability.current - damageApplied
            -- Only grant XP if asteroid is destroyed this frame
            if durability.current <= 0 then
                UISystem.addSkillExperience("mining", 10)
            end
        end
        -- Store color of hit asteroid
        local renderable = ECS.getComponent(hitAsteroidId, "Renderable")
        closestIntersection.color = renderable and renderable.color or {0.6, 0.4, 0.2, 1}
        -- Create impact debris
        DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, closestIntersection.color)
        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

return MiningLaser
