-- Laser Turret Module
-- This module defines the behavior of a standard laser turret.

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local EntityPool = require('src.entity_pool')

local MiningLaser = {
    name = "mining_laser",
    displayName = "Mining Laser",
    CONTINUOUS = true,
    HEAT_RATE = 2.0, -- Heat units per second while firing
    MAX_HEAT = 10.0, -- Max heat before overheating
    COOL_RATE = 3.0, -- Heat units per second while not firing
    DPS = 50,
    RANGE = math.huge,  -- Unlimited beam range for visual collision
    -- Damage falloff configuration
    FALLOFF_START = 400,   -- Full damage up to this distance
    FALLOFF_END = 1350,    -- Zero damage beyond this distance
    ZERO_DAMAGE_RANGE = 1350,  -- Maximum effective range (beyond this deals no damage)
    design = {
        shape = "custom",
        size = 16,
        color = {1.0, 1.0, 0, 1}  -- Full vibrant yellow
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.2, 0.2, 0.05, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(1, 1, 0.3, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(1, 1, 0.7, 0.6)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(1, 1, 0.3, 0.7)
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
    
    -- Release old laser if it exists (return to pool instead of destroying)
    if turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            EntityPool.release("laser_beam", turretComp.laserEntity)
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
    
    -- Acquire laser beam entity from pool
    turretComp.laserEntity = EntityPool.acquire("laser_beam")
    
    -- Calculate beam length for collision radius
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)
    
    -- Calculate midpoint for position (for depth sorting and rendering order)
    local midX = (offsetStartX + endX) / 2
    local midY = (offsetStartY + endY) / 2
    
    -- Update position and collision components on the pooled entity
    local posComp = ECS.getComponent(turretComp.laserEntity, "Position")
    if posComp then
        posComp.x = midX
        posComp.y = midY
    end
    
    local collidable = ECS.getComponent(turretComp.laserEntity, "Collidable")
    if collidable then
        collidable.radius = beamLength / 2 + 10
    end
    
    -- Update laser beam component with new data
    local laserComp = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
    if laserComp then
        laserComp.start = {x = offsetStartX, y = offsetStartY}
        laserComp.endPos = {x = endX, y = endY}
        laserComp.color = {1, 1, 0, 1}  -- Vibrant yellow
        laserComp.ownerId = ownerId
    end
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
            -- Update laser visual to end at collision point instead of aim point
            local laserComp = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
            if laserComp then
                laserComp.endPos = {x = closestIntersection.x, y = closestIntersection.y}
            end
            
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

                -- Check for hotspot bonus: if asteroid has a hotspot and hit is near it
                local hotspotMultiplier = 1.0
                local hotspotEntities = ECS.getEntitiesWith({"Hotspot", "Attached", "Position"})
                for _, hotspotId in ipairs(hotspotEntities) do
                    local attached = ECS.getComponent(hotspotId, "Attached")
                    if attached and attached.parentId == hitAsteroidId then
                        local hotspotPos = ECS.getComponent(hotspotId, "Position")
                        local hotspot = ECS.getComponent(hotspotId, "Hotspot")
                        if hotspotPos and hotspot then
                            -- Check if hit point is within hotspot radius (15 units)
                            local dx = closestIntersection.x - hotspotPos.x
                            local dy = closestIntersection.y - hotspotPos.y
                            local distSq = dx * dx + dy * dy
                            if distSq < 15 * 15 then
                                hotspotMultiplier = hotspot.dpsMultiplier
                                break
                            end
                        end
                    end
                end

                -- Calculate final damage
                local baseDamage = MiningLaser.DPS * dt
                local finalDamage = baseDamage * distanceMultiplier * heatMultiplier * hotspotMultiplier
                local damageApplied = math.min(finalDamage, durability.current)
                durability.current = durability.current - damageApplied

                -- Track who is damaging this asteroid
                local ownerEntity = ECS.getComponent(ownerId, "ControlledBy")
                if ownerEntity and ownerEntity.pilotId then
                    ECS.addComponent(hitAsteroidId, "LastDamager", Components.LastDamager(ownerEntity.pilotId, "mining_laser"))
                end
                
                -- Mark asteroid as being mined (for hotspot spawning)
                local currentTime = love.timer.getTime()
                ECS.addComponent(hitAsteroidId, "BeingMined", Components.BeingMined(currentTime))
                
                -- Enhanced visual feedback: More particles as asteroid gets damaged
                local asteroidHealthPercent = durability.current / durability.max
                local particleCount = math.floor(1 + (1 - asteroidHealthPercent) * 3)  -- 1-4 particles
                DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, particleCount, {1, 1, 0, 1})
            end
        end
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
            EntityPool.release("laser_beam", turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
end

return MiningLaser
