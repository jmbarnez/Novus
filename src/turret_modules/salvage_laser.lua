---@diagnostic disable: undefined-global
-- Salvage Laser Turret Module
-- This module defines a laser that can harvest scrap from wreckage

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local UISystem = require('src.systems.ui')

local SalvageLaser = {
    name = "salvage_laser",
    LASER_DPS = 40,
    laserEntity = nil  -- Track the current laser beam entity
}

-- Fire the laser - creates and maintains laser beam entity
function SalvageLaser.fire(ownerId, startX, startY, endX, endY)
    -- Destroy old laser if it exists
    if SalvageLaser.laserEntity then
        local component = ECS.getComponent(SalvageLaser.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(SalvageLaser.laserEntity)
        end
    end
    
    -- Create new laser beam entity
    SalvageLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(SalvageLaser.laserEntity, "LaserBeam", {
        start = {x = startX, y = startY},
        endPos = {x = endX, y = endY}
    })
    -- Mark this entity as a salvage laser projectile for wreckage harvesting
    ECS.addComponent(SalvageLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = SalvageLaser.LASER_DPS, brittle = false, isSalvageLaser = true})
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
function SalvageLaser.applyBeam(ownerId, startX, startY, endX, endY, dt)
    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitWreckageId = nil

    -- Check for wreckage hits
    local wreckageEntities = ECS.getEntitiesWith({"Wreckage", "Collidable", "Position", "PolygonShape", "Durability"})
    for _, wreckageId in ipairs(wreckageEntities) do
        local intersection = CollisionSystem.linePolygonIntersect(startX, startY, endX, endY, wreckageId)
        if intersection then
            local distSq = (intersection.x - startX)^2 + (intersection.y - startY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitWreckageId = wreckageId
            end
        end
    end

    if closestIntersection and hitWreckageId then
        -- Apply per-frame DPS to wreckage
        local durability = ECS.getComponent(hitWreckageId, "Durability")
        if durability then
            local damageApplied = math.min(SalvageLaser.LASER_DPS * dt, durability.current)
            durability.current = durability.current - damageApplied
            -- Only grant XP if wreckage is destroyed this frame
            if durability.current <= 0 then
                UISystem.addSkillExperience("salvage", 5)
            end
        end
        -- Store color of hit wreckage
        local renderable = ECS.getComponent(hitWreckageId, "Renderable")
        closestIntersection.color = renderable and renderable.color or {0.5, 0.5, 0.5, 1}
        -- Create impact debris
        DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, closestIntersection.color)
        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

return SalvageLaser
