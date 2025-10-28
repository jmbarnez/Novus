---@diagnostic disable: undefined-global
-- Continuous Beam Module
-- A unified laser that can handle combat, mining, and salvaging

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')
local EntityPool = require('src.entity_pool')
local EntityHelpers = require('src.entity_helpers')
local LaserAudio = require('src.turret_modules.laser_audio')

local ContinuousBeam = {
    name = "continuous_beam",
    displayName = "Continuous Beam Module",
    CONTINUOUS = true,
    HEAT_RATE = 3.0,
    MAX_HEAT = 12.0,
    COOL_RATE = 3.0,
    DPS = 20,
    RANGE = math.huge,  -- Unlimited beam range for visual collision
    -- Damage falloff configuration
    FALLOFF_START = 350,
    FALLOFF_END = 1200,
    ZERO_DAMAGE_RANGE = 1200,
    design = {
        shape = "custom",
        size = 16,
        color = {0, 0.7, 1, 1}  -- Vibrant cyan blue
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.05, 0.1, 0.15, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(0, 0.7, 1, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(0.2, 0.8, 1, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(0.6, 0.9, 1, 0.3)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(0, 0.6, 0.9, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(0.2, 0.7, 0.9, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        love.graphics.setColor(0.06, 0.06, 0.075, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end
}

-- Fire the laser - creates and maintains laser beam entity
function ContinuousBeam.fire(ownerId, startX, startY, endX, endY, turretComp)
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
    
    -- Calculate midpoint for position (for depth sorting and rendering order)
    local midX = (offsetStartX + endX) / 2
    local midY = (offsetStartY + endY) / 2
    
    -- Calculate beam length for collision radius
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)
    
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
        laserComp.color = {0, 0.7, 1, 1}  -- Vibrant cyan blue
        laserComp.ownerId = ownerId
    end

    LaserAudio.start(turretComp)
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position (ship center)
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function ContinuousBeam.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
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

    LaserAudio.start(turretComp, nil, {x = offsetStartX, y = offsetStartY})

    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitEntityId = nil

    -- Check for collisions with any collidable polygon entity (ships, asteroids, wreckage, etc)
    local entityEntities = ECS.getEntitiesWith({"Position", "PolygonShape", "Collidable"})
    for _, entityId in ipairs(entityEntities) do
        -- Skip hitting ourselves
        if entityId == ownerId then goto skip_entity end

        local intersection = CollisionSystem.linePolygonIntersect(offsetStartX, offsetStartY, endX, endY, entityId)
        
        if intersection then
            local distSq = (intersection.x - offsetStartX)^2 + (intersection.y - offsetStartY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitEntityId = entityId
            end
        end

        ::skip_entity::
    end

    if closestIntersection and hitEntityId then
        local debrisCreated = false
        -- Calculate distance from laser origin to hit point for falloff
        local hitDistance = math.sqrt(closestDistSq)

        -- Distance falloff: damage starts falling off after FALLOFF_START units
        local falloffStart = ContinuousBeam.FALLOFF_START
        local falloffEnd = ContinuousBeam.FALLOFF_END
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
            local heatProgress = turretComp.heat.current / ContinuousBeam.MAX_HEAT
            heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
        end

        -- Calculate final damage
        local baseDamage = ContinuousBeam.DPS * dt
        local finalDamage = baseDamage * distanceMultiplier * heatMultiplier
        
        -- Detect target type and apply appropriate damage
        local hull = ECS.getComponent(hitEntityId, "Hull")
        local asteroid = ECS.getComponent(hitEntityId, "Asteroid")
        local wreckage = ECS.getComponent(hitEntityId, "Wreckage")
        
        -- Combat damage: target has Hull (ships, enemies)
        if hull then
            -- Check for mirror first: if entity has Ability component with mirror type, reflect the laser
            local abilityComp = ECS.getComponent(hitEntityId, "Ability")
            local isMirror = abilityComp and abilityComp.abilityType == "mirror"
            if isMirror then
                -- Compute incoming vector
                local inVecX = closestIntersection.x - offsetStartX
                local inVecY = closestIntersection.y - offsetStartY
                local inLen = math.sqrt(inVecX*inVecX + inVecY*inVecY)
                if inLen > 0 then inVecX, inVecY = inVecX / inLen, inVecY / inLen end

                -- Mirror normal approximated by mirror's dir (mirror faces dir)
                local dir = abilityComp and abilityComp.dir or {x = 0, y = 1}
                local nx, ny = dir.x or 0, dir.y or 1
                -- Reflect vector: r = v - 2*(v·n)*n
                local dot = inVecX * nx + inVecY * ny
                local rx = inVecX - 2 * dot * nx
                local ry = inVecY - 2 * dot * ny

                -- Fire a reflected beam from the intersection point in reflected direction for the remaining distance
                local reflectEndX = closestIntersection.x + rx * 800
                local reflectEndY = closestIntersection.y + ry * 800

                -- Attempt to apply damage along reflected path (single bounce)
                local entityEntities = ECS.getEntitiesWith({"Position", "PolygonShape", "Collidable"})
                local closestDistSq2 = math.huge
                local closestIntersection2 = nil
                local hitEntityId2 = nil
                for _, entityId2 in ipairs(entityEntities) do
                    if entityId2 == ownerId or entityId2 == hitEntityId then goto skip_reflect end
                    local inter2 = CollisionSystem.linePolygonIntersect(closestIntersection.x + rx*1, closestIntersection.y + ry*1, reflectEndX, reflectEndY, entityId2)
                    if inter2 then
                        local distSq2 = (inter2.x - closestIntersection.x)^2 + (inter2.y - closestIntersection.y)^2
                        if distSq2 < closestDistSq2 then
                            closestDistSq2 = distSq2
                            closestIntersection2 = inter2
                            hitEntityId2 = entityId2
                        end
                    end
                    ::skip_reflect::
                end

                if closestIntersection2 and hitEntityId2 then
                    local hull2 = ECS.getComponent(hitEntityId2, "Hull")
                    if hull2 then
                        local shield2 = ECS.getComponent(hitEntityId2, "Shield")
                        local damage2 = finalDamage * 0.8 -- some loss on reflection
                        if shield2 and shield2.current > 0 then
                            EntityHelpers.createShieldImpact(closestIntersection2.x, closestIntersection2.y, hitEntityId2)
                            local remaining2 = shield2.current - damage2
                            shield2.current = math.max(0, remaining2)
                            damage2 = math.max(0, -remaining2)
                            shield2.regenTimer = shield2.regenDelay or 0
                            
                            -- Notify AI system of damage
                            EntityHelpers.notifyAIDamage(hitEntityId2, ownerId)
                        end
                        if damage2 > 0 then
                            local applied = math.min(damage2, hull2.current)
                            hull2.current = hull2.current - applied
                            
                            -- Notify AI system of damage for aggressive reaction
                            EntityHelpers.notifyAIDamage(hitEntityId2, ownerId)
                            
                            if hull2.current <= 0 then SkillXP.awardXp("combat") end
                        end
                    else
                        DebrisSystem.createDebris(closestIntersection2.x, closestIntersection2.y, 1, ContinuousBeam.design.color)
                    end
                else
                    -- missed, spawn debris at reflection endpoint
                    DebrisSystem.createDebris(closestIntersection.x + rx*30, closestIntersection.y + ry*30, 1, ContinuousBeam.design.color)
                end

                -- Visual impact on mirror
                DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, {1,1,0.6,1})
                return {hit = true, intersection = closestIntersection}
            end

            -- Apply damage to Shield first, then Hull
            local shield = ECS.getComponent(hitEntityId, "Shield")
            local damage = finalDamage

            if shield and shield.current > 0 then
                -- Shield absorbed damage - create impact effect
                EntityHelpers.createShieldImpact(closestIntersection.x, closestIntersection.y, hitEntityId)

                local remaining = shield.current - damage
                shield.current = math.max(0, remaining)
                damage = math.max(0, -remaining)
                shield.regenTimer = shield.regenDelay or 0
                
                -- Notify AI system of damage even if only shield hit
                EntityHelpers.notifyAIDamage(hitEntityId, ownerId)
            end

            if damage > 0 then
                local damageApplied = math.min(damage, hull.current)
                hull.current = hull.current - damageApplied

                -- Notify AI system of damage for aggressive reaction
                EntityHelpers.notifyAIDamage(hitEntityId, ownerId)

                -- Only grant XP if ship is destroyed this frame
                if hull.current <= 0 then
                    SkillXP.awardXp("combat")
                end
            end
            debrisCreated = true
        -- Mining damage: target is an asteroid
        elseif asteroid then
            local durability = ECS.getComponent(hitEntityId, "Durability")
            if durability then
                local damageApplied = math.min(finalDamage, durability.current)
                durability.current = durability.current - damageApplied

                -- Track who is damaging this asteroid
                local ownerEntity = ECS.getComponent(ownerId, "ControlledBy")
                if ownerEntity and ownerEntity.pilotId then
                    local EntityHelpers = require('src.entity_helpers')
                    EntityHelpers.recordLastDamager(hitEntityId, ownerEntity.pilotId, "continuous_beam")
                end
                
                -- Enhanced visual feedback: More particles as asteroid gets damaged
                local asteroidHealthPercent = durability.current / durability.max
                local particleCount = math.floor(1 + (1 - asteroidHealthPercent) * 3)  -- 1-4 particles
                DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, particleCount, {0, 0.7, 1, 1})
                debrisCreated = true
            end
        -- Salvaging damage: target is wreckage
        elseif wreckage then
            local durability = ECS.getComponent(hitEntityId, "Durability")
            if durability then
                local damageApplied = math.min(finalDamage, durability.current)
                durability.current = durability.current - damageApplied
                -- Only grant XP if wreckage is destroyed this frame
                if durability.current <= 0 then
                    SkillXP.awardXp("salvaging")
                end
                DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, {0, 0.7, 1, 1})
                debrisCreated = true
            end
        end

        -- If we didn't create debris via target-specific logic, spawn a simple impact particle
        if not debrisCreated then
            DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, ContinuousBeam.design.color)
        end

        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

-- Stop firing - clean up laser beam entity
function ContinuousBeam.stopFiring(turretComp)
    if turretComp and turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            EntityPool.release("laser_beam", turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
    LaserAudio.stop(turretComp)
end

return ContinuousBeam

