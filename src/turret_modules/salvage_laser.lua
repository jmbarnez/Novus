---@diagnostic disable: undefined-global
-- Salvage Laser Turret Module
-- This module defines a laser that can harvest scrap from wreckage

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')

local SalvageLaser = {
    name = "salvage_laser",
    displayName = "Salvage Laser",
    CONTINUOUS = true,
    HEAT_RATE = 2.0, -- Heat units per second while firing
    MAX_HEAT = 10.0, -- Max heat before overheating
    COOL_RATE = 3.0, -- Heat units per second while not firing
    DPS = 30,
    RANGE = math.huge,  -- Unlimited beam range for visual collision
    -- Damage falloff configuration
    FALLOFF_START = 350,   -- Full damage up to this distance
    FALLOFF_END = 1200,    -- Zero damage beyond this distance
    ZERO_DAMAGE_RANGE = 1200,  -- Maximum effective range (beyond this deals no damage)
    design = {
        shape = "custom",
        size = 16,
        color = {0.8, 0.4, 1, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.1, 0.15, 0.1, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(0.4, 1, 0.4, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(0.2, 1, 0.2, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(0.4, 1, 0.4, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        love.graphics.setColor(0.12, 0.15, 0.12, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end
}

-- Fire the laser - creates and maintains laser beam entity
function SalvageLaser.fire(ownerId, startX, startY, endX, endY, turretComp)
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
    
    -- Calculate midpoint for position (for depth sorting and rendering order)
    local midX = (offsetStartX + endX) / 2
    local midY = (offsetStartY + endY) / 2
    
    -- Calculate beam length for collision radius
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)
    
    ECS.addComponent(turretComp.laserEntity, "Position", Components.Position(midX, midY))
    -- Add collision component so laser can collide with entities
    ECS.addComponent(turretComp.laserEntity, "Collidable", Components.Collidable(beamLength / 2 + 10))
    ECS.addComponent(turretComp.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = endX, y = endY},
        color = {0.2, 1, 0.2, 1},  -- Green
        ownerId = ownerId
    })
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function SalvageLaser.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
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
    local hitEntityId = nil

    -- Check for collisions with any collidable polygon entity (asteroids, ships, wreckage, etc)
    local entityEntities = ECS.getEntitiesWith({"Collidable", "Position", "PolygonShape"})
    for _, entityId in ipairs(entityEntities) do
        local intersection = CollisionSystem.linePolygonIntersect(offsetStartX, offsetStartY, endX, endY, entityId)
        if intersection then
            local distSq = (intersection.x - offsetStartX)^2 + (intersection.y - offsetStartY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitEntityId = entityId
            end
        end
    end

    if closestIntersection and hitEntityId then
        -- Only apply damage if target is wreckage
        local isWrackage = ECS.getComponent(hitEntityId, "Wreckage")
        if isWrackage then
            local durability = ECS.getComponent(hitEntityId, "Durability")
            if durability then
                -- Calculate distance from laser origin to hit point
                local hitDistance = math.sqrt(closestDistSq)

                -- Distance falloff: damage starts falling off after 350 units, reaches 0 at 1100
                local falloffStart = 350
                local falloffEnd = 1100
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
                    local heatProgress = turretComp.heat.current / SalvageLaser.MAX_HEAT
                    heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
                end

                -- Calculate final damage
                local baseDamage = SalvageLaser.DPS * dt
                local finalDamage = baseDamage * distanceMultiplier * heatMultiplier
                local damageApplied = math.min(finalDamage, durability.current)
                durability.current = durability.current - damageApplied
                -- Only grant XP if wreckage is destroyed this frame
                if durability.current <= 0 then
                    SkillXP.awardXp("salvaging")
                end
            end
        end
        -- Create impact debris with laser beam color
        DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, {0.2, 1, 0.2, 1})
        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

-- Stop firing - clean up laser beam entity
function SalvageLaser.stopFiring(turretComp)
    if turretComp and turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
end

return SalvageLaser
