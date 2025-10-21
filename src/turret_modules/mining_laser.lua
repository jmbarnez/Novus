-- Laser Turret Module
-- This module defines the behavior of a standard laser turret.

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')

local MiningLaser = {
    name = "mining_laser",
    displayName = "Mining Laser",
    CONTINUOUS = true,
    HEAT_RATE = 2.0, -- Heat units per second while firing
    MAX_HEAT = 10.0, -- Max heat before overheating
    COOL_RATE = 3.0, -- Heat units per second while not firing
    DPS = 50,
    RANGE = 1350,
    design = {
        shape = "custom",
        size = 16,
        color = {1.0, 1.0, 0.2, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.2, 0.15, 0.1, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(1, 1, 0.2, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(1, 1, 0.4, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(1, 0.8, 0.2, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(1, 0.9, 0.4, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        love.graphics.setColor(0.12, 0.12, 0.15, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end,
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
    
    -- Offset start position away from owner ship to avoid self-collision
    local offsetStartX = startX
    local offsetStartY = startY
    local ownerCollidable = ECS.getComponent(ownerId, "Collidable")
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
    MiningLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(MiningLaser.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = endX, y = endY},
        color = {1, 1, 0, 1}  -- Yellow
    })
    -- Mark this entity as a mining laser projectile for asteroid damage
    ECS.addComponent(MiningLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = MiningLaser.DPS, brittle = false, isMiningLaser = true})
    -- ...existing code...
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function MiningLaser.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
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
            -- Calculate distance from laser origin to hit point
            local hitDistance = math.sqrt(closestDistSq)

            -- Distance falloff: damage starts falling off after 675 units, reaches 50% at max range (1350)
            local falloffStart = 675
            local falloffEnd = MiningLaser.RANGE
            local distanceMultiplier = 1.0
            if hitDistance > falloffStart then
                local falloffRange = falloffEnd - falloffStart
                local falloffProgress = math.min((hitDistance - falloffStart) / falloffRange, 1.0)
                distanceMultiplier = 1.0 - (falloffProgress * 0.5)  -- Falls to 50% damage
            end

            -- Heat multiplier: damage increases from 1x at 0 heat to 2x at max heat
            local heatMultiplier = 1.0
            if turretComp and turretComp.heat then
                local heatProgress = turretComp.heat / MiningLaser.MAX_HEAT
                heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
            end

            -- Calculate final damage
            local baseDamage = MiningLaser.DPS * dt
            local finalDamage = baseDamage * distanceMultiplier * heatMultiplier
            local damageApplied = math.min(finalDamage, durability.current)
            durability.current = durability.current - damageApplied

            -- Track who is damaging this asteroid
            local ownerEntity = ECS.getComponent(ownerId, "ControlledBy")
            if ownerEntity and ownerEntity.pilotId then
                ECS.addComponent(hitAsteroidId, "LastDamager", Components.LastDamager(ownerEntity.pilotId, "mining_laser"))
            end

            -- Only grant XP if asteroid is destroyed this frame
            if durability.current <= 0 then
                SkillXP.awardXp("mining")
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

-- Stop firing - clean up laser beam entity
function MiningLaser.stopFiring()
    if MiningLaser.laserEntity then
        local component = ECS.getComponent(MiningLaser.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(MiningLaser.laserEntity)
        end
        MiningLaser.laserEntity = nil
    end
end

return MiningLaser
