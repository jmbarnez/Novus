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
    RANGE = math.huge,  -- Unlimited beam range for visual collision
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
    end
}

-- Fire the laser - creates and maintains laser beam entity
function MiningLaser.fire(ownerId, startX, startY, endX, endY, turretComp)
    -- Store laser on turret component so each turret can have its own laser
    if not turretComp then return end
    
    -- Destroy old laser if it exists
    if turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(turretComp.laserEntity)
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
    turretComp.laserEntity = ECS.createEntity()
    
    -- Calculate beam length for collision radius
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)
    
    ECS.addComponent(turretComp.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = endX, y = endY},
        color = {1, 1, 0.2, 1},  -- Bright yellow
        ownerId = ownerId
    })
    -- Add position for collision tracking
    local midX = (offsetStartX + endX) / 2
    local midY = (offsetStartY + endY) / 2
    ECS.addComponent(turretComp.laserEntity, "Position", Components.Position(midX, midY))
    -- Add collision component so laser can collide with entities
    ECS.addComponent(turretComp.laserEntity, "Collidable", Components.Collidable(beamLength / 2 + 10))
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function MiningLaser.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
    -- Offset start position to barrel end to match where laser visually originates
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

    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitAsteroidId = nil

    -- Check for collisions with all collidable polygon entities (asteroids, ships, wreckage, etc)
    local allEntities = ECS.getEntitiesWith({"Collidable", "Position", "PolygonShape"})
    for _, entityId in ipairs(allEntities) do
        local intersection = CollisionSystem.linePolygonIntersect(offsetStartX, offsetStartY, endX, endY, entityId)
        if intersection then
            local distSq = (intersection.x - offsetStartX)^2 + (intersection.y - offsetStartY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitAsteroidId = entityId
            end
        end
    end

    if closestIntersection and hitAsteroidId then
        -- Only apply damage if target is an asteroid
        local isAsteroid = ECS.getComponent(hitAsteroidId, "Asteroid")
        if isAsteroid then
            local durability = ECS.getComponent(hitAsteroidId, "Durability")
            if durability then
                -- Calculate distance from laser origin to hit point
                local hitDistance = math.sqrt(closestDistSq)

                -- Distance falloff: damage starts falling off after 400 units, reaches 0 at 1350
                local falloffStart = 400
                local falloffEnd = 1350
                local distanceMultiplier = 1.0
                if hitDistance > falloffStart then
                    local falloffRange = falloffEnd - falloffStart
                    local falloffProgress = math.min((hitDistance - falloffStart) / falloffRange, 1.0)
                    distanceMultiplier = 1.0 - (falloffProgress * 1.0)  -- Falls to 0% damage at max
                    if distanceMultiplier < 0 then distanceMultiplier = 0 end
                end

                -- Heat multiplier: damage increases from 1x at 0 heat to 2x at max heat
                local heatMultiplier = 1.0
                if turretComp and turretComp.heat then
                    local heatProgress = turretComp.heat.current / MiningLaser.MAX_HEAT
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
        end
        -- Store color of hit entity
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
function MiningLaser.stopFiring(turretComp)
    if turretComp and turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
end

return MiningLaser
