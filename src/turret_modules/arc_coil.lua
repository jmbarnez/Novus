---@diagnostic disable: undefined-global
-- Arc Coil Turret Module
-- Continuous lightning beam that arcs once to a nearby target

local ECS = require('src.ecs')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')
local EntityPool = require('src.entity_pool')
local LaserAudio = require('src.turret_modules.laser_audio')

local ArcCoil = {
    name = "arc_coil",
    displayName = "Arc Coil",
    CONTINUOUS = true,
    HEAT_RATE = 3.5,
    MAX_HEAT = 12.0,
    COOL_RATE = 3.5,
    DPS = 20,
    RANGE = 700,
    JUMP_RADIUS = 800,
    JUMP_DAMAGE_MULTIPLIER = 0.5,
    ENERGY_PER_SECOND = 22,
    design = {
        shape = "custom",
        size = 18,
        color = {0.65, 0.85, 1.0, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.12, 0.12, 0.18, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 4, 4)
        love.graphics.setColor(0.4, 0.7, 1.0, 1)
        love.graphics.circle("fill", x, y - size/3, size/3)
        love.graphics.setColor(0.75, 0.9, 1.0, 0.9)
        love.graphics.circle("fill", x, y - size/3, size/5)
        love.graphics.setColor(0.25, 0.25, 0.35, 1)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.6, size/4, 3, 3)
        love.graphics.setColor(0.55, 0.8, 1.0, 0.7)
        love.graphics.rectangle("fill", x - size/4, y + size/4 + 2, size/2, size/6)
    end
}

local coilColor = {0.6, 0.85, 1.0, 1}
local chainColor = {0.8, 0.95, 1.0, 1}
local rng = (love and love.math and love.math.random) or math.random

local function generateLightningSegments(x1, y1, x2, y2)
    local points = {}
    points[#points + 1] = {x = x1, y = y1}

    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then
        points[#points + 1] = {x = x2, y = y2}
        return points
    end

    local segmentCount = math.max(2, math.floor(dist / 45))
    local normalX = -dy / dist
    local normalY = dx / dist
    local maxOffset = math.min(24, dist * 0.3)

    for i = 1, segmentCount - 1 do
        local t = i / segmentCount
        local falloff = 1 - math.abs(t - 0.5) * 1.4
        local magnitude = (rng() * 2 - 1) * maxOffset * falloff
        local px = x1 + dx * t + normalX * magnitude
        local py = y1 + dy * t + normalY * magnitude
        points[#points + 1] = {x = px, y = py}
    end

    points[#points + 1] = {x = x2, y = y2}
    return points
end

local function clampToRange(startX, startY, targetX, targetY, range)
    local dx = targetX - startX
    local dy = targetY - startY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist <= range then
        return targetX, targetY
    end
    if dist == 0 then
        return startX, startY
    end
    local scale = range / dist
    return startX + dx * scale, startY + dy * scale
end

-- Previously we filtered targets by Hull/Shield; change to allow any collidable entity to be hit.

local function applyDamage(entityId, damageAmount)
    if damageAmount <= 0 then
        return false
    end

    local shield = ECS.getComponent(entityId, "Shield")
    local hull = ECS.getComponent(entityId, "Hull")
    local damage = damageAmount
    local dealtDamage = false

    if shield and shield.current and shield.current > 0 then
        local remaining = shield.current - damage
        shield.current = math.max(0, remaining)
        shield.regenTimer = shield.regenDelay or 0
        damage = math.max(0, -remaining)
        dealtDamage = true
    end

    if damage > 0 and hull and hull.current and hull.current > 0 then
        local before = hull.current
        hull.current = math.max(0, hull.current - damage)
        if before > 0 and hull.current <= 0 then
            SkillXP.awardXp("combat")
        end
        dealtDamage = true
    end

    return dealtDamage
end

local function findPrimaryHit(ownerId, startX, startY, endX, endY)
    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitEntityId = nil

    local collidableEntities = ECS.getEntitiesWith({"Position", "PolygonShape", "Collidable"})
    for _, entityId in ipairs(collidableEntities) do
        -- Only skip ourselves; any other collidable entity is a valid target
        if entityId ~= ownerId then
            local intersection = CollisionSystem.linePolygonIntersect(startX, startY, endX, endY, entityId)
            if intersection then
                local distSq = (intersection.x - startX) * (intersection.x - startX) + (intersection.y - startY) * (intersection.y - startY)
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    closestIntersection = intersection
                    hitEntityId = entityId
                end
            end
        end
    end

    if hitEntityId then
        return {
            entityId = hitEntityId,
            intersection = closestIntersection
        }
    end
    return nil
end

local function findChainTarget(primaryId, ownerId, radius)
    -- Only search for enemy Hull targets for chaining
    local primaryPos = ECS.getComponent(primaryId, "Position")
    if not primaryPos then
        return nil
    end

    local radiusSq = radius * radius
    local bestId = nil
    local bestDistSq = math.huge

    local hullTargets = ECS.getEntitiesWith({"Position", "Hull"})
    for _, candidateId in ipairs(hullTargets) do
        if candidateId ~= primaryId and candidateId ~= ownerId then
            local candidateHull = ECS.getComponent(candidateId, "Hull")
            if candidateHull and candidateHull.current and candidateHull.current > 0 then
                local candidatePos = ECS.getComponent(candidateId, "Position")
                if candidatePos then
                    local dx = candidatePos.x - primaryPos.x
                    local dy = candidatePos.y - primaryPos.y
                    local distSq = dx * dx + dy * dy
                    if distSq <= radiusSq and distSq < bestDistSq then
                        bestDistSq = distSq
                        bestId = candidateId
                    end
                end
            end
        end
    end

    if bestId then
        return bestId
    end
    return nil
end

-- Fire the beam - maintain pooled laser entity for visuals
function ArcCoil.fire(ownerId, startX, startY, endX, endY, turretComp)
    if not turretComp then
        return
    end

    if turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            EntityPool.release("laser_beam", turretComp.laserEntity)
        end
    end

    local offsetStartX = startX
    local offsetStartY = startY
    local ownerCollidable = ECS.getComponent(ownerId, "Collidable")
    if ownerCollidable then
        local dx = endX - startX
        local dy = endY - startY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            -- Use a smaller offset to start closer to the ship's edge
            offsetStartX = startX + (dx / dist) * (ownerCollidable.radius + 2)
            offsetStartY = startY + (dy / dist) * (ownerCollidable.radius + 2)
        end
    end
    endX, endY = clampToRange(offsetStartX, offsetStartY, endX, endY, ArcCoil.RANGE)

    turretComp.laserEntity = EntityPool.acquire("laser_beam")

    local midX = (offsetStartX + endX) / 2
    local midY = (offsetStartY + endY) / 2
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)

    local posComp = ECS.getComponent(turretComp.laserEntity, "Position")
    if posComp then
        posComp.x = midX
        posComp.y = midY
    end

    local collidable = ECS.getComponent(turretComp.laserEntity, "Collidable")
    if collidable then
        collidable.radius = beamLength / 2 + 10
    end

    local laserComp = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
    if laserComp then
        laserComp.start = {x = offsetStartX, y = offsetStartY}
        laserComp.endPos = {x = endX, y = endY}
        laserComp.color = {coilColor[1], coilColor[2], coilColor[3], coilColor[4]}
        laserComp.ownerId = ownerId
        laserComp.segments = nil
        laserComp.chainSegments = nil
        laserComp.chainColor = nil
    end

    LaserAudio.start(turretComp, nil, {x = offsetStartX, y = offsetStartY})
end

-- Apply beam logic each frame
function ArcCoil.applyBeam(ownerId, startX, startY, targetX, targetY, dt, turretComp)
    -- startX, startY already comes from input.lua as the offset muzzle position
    -- No need to offset again here
    local offsetStartX = startX
    local offsetStartY = startY

    LaserAudio.start(turretComp, nil, {x = offsetStartX, y = offsetStartY})

    targetX, targetY = clampToRange(offsetStartX, offsetStartY, targetX, targetY, ArcCoil.RANGE)
    local beamEnd = {x = targetX, y = targetY}

    local laserComp = nil
    if turretComp and turretComp.laserEntity then
        laserComp = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
    end

    local primaryHit = findPrimaryHit(ownerId, offsetStartX, offsetStartY, targetX, targetY)
    if not primaryHit then
        if laserComp then
            laserComp.segments = generateLightningSegments(offsetStartX, offsetStartY, targetX, targetY)
            laserComp.chainSegments = nil
            laserComp.chainColor = nil
        end
        return {hit = false, endPos = beamEnd}
    end

    local baseDamage = ArcCoil.DPS * (dt or 0)
    local debrisCreated = false

    -- Determine target type and apply appropriate damage (ships, asteroids, wreckage)
    local hitId = primaryHit.entityId
    local hull = ECS.getComponent(hitId, "Hull")
    local asteroid = ECS.getComponent(hitId, "Asteroid")
    local wreckage = ECS.getComponent(hitId, "Wreckage")
    local EntityHelpers = require('src.entity_helpers')

    if hull then
        -- Apply to shield first, then hull
        local shield = ECS.getComponent(hitId, "Shield")
        local damage = baseDamage
        if shield and shield.current > 0 then
            EntityHelpers.createShieldImpact(primaryHit.intersection.x, primaryHit.intersection.y, hitId)
            local remaining = shield.current - damage
            shield.current = math.max(0, remaining)
            damage = math.max(0, -remaining)
            shield.regenTimer = shield.regenDelay or 0
            EntityHelpers.notifyAIDamage(hitId, ownerId)
        end

        if damage > 0 then
            local applied = math.min(damage, hull.current)
            hull.current = hull.current - applied
            EntityHelpers.notifyAIDamage(hitId, ownerId)
            if hull.current <= 0 then SkillXP.awardXp("combat") end
            debrisCreated = true
        end

    elseif asteroid then
        local durability = ECS.getComponent(hitId, "Durability")
        if durability then
            -- Asteroids take 1/10th damage from Arc Coil
            local scaledDamage = baseDamage * 0.1
            local damageApplied = math.min(scaledDamage, durability.current)
            durability.current = durability.current - damageApplied

            local ownerEntity = ECS.getComponent(ownerId, "ControlledBy")
            if ownerEntity and ownerEntity.pilotId then
                EntityHelpers.recordLastDamager(hitId, ownerEntity.pilotId, "arc_coil")
            end

            DebrisSystem.createDebris(primaryHit.intersection.x, primaryHit.intersection.y, 1, coilColor)
            debrisCreated = true
        end

    elseif wreckage then
        local durability = ECS.getComponent(hitId, "Durability")
        if durability then
            -- Wreckage takes 1/10th damage from Arc Coil
            local scaledDamage = baseDamage * 0.1
            local damageApplied = math.min(scaledDamage, durability.current)
            durability.current = durability.current - damageApplied
            if durability.current <= 0 then SkillXP.awardXp("salvaging") end
            DebrisSystem.createDebris(primaryHit.intersection.x, primaryHit.intersection.y, 1, coilColor)
            debrisCreated = true
        end
    end

    if not debrisCreated then
        DebrisSystem.createDebris(primaryHit.intersection.x, primaryHit.intersection.y, 1, coilColor)
    end

    -- Handle chain damage to another nearby collidable
    -- Only attempt chaining if primary hit was an enemy (has Hull)
    local chainTargetId = nil
    local primaryHull = ECS.getComponent(primaryHit.entityId, "Hull")
    if primaryHull then
        chainTargetId = findChainTarget(primaryHit.entityId, ownerId, ArcCoil.JUMP_RADIUS)
    end
    local chainImpactPos = nil
    if chainTargetId then
        local secondaryDamage = baseDamage * ArcCoil.JUMP_DAMAGE_MULTIPLIER
        local chainHull = ECS.getComponent(chainTargetId, "Hull")
        local chainAsteroid = ECS.getComponent(chainTargetId, "Asteroid")
        local chainWreck = ECS.getComponent(chainTargetId, "Wreckage")
        local chainPosComp = ECS.getComponent(chainTargetId, "Position")

        if chainHull then
            local shield2 = ECS.getComponent(chainTargetId, "Shield")
            local damage2 = secondaryDamage
            if shield2 and shield2.current > 0 then
                if chainPosComp then
                    EntityHelpers.createShieldImpact(chainPosComp.x, chainPosComp.y, chainTargetId)
                end
                local remaining2 = shield2.current - damage2
                shield2.current = math.max(0, remaining2)
                damage2 = math.max(0, -remaining2)
                shield2.regenTimer = shield2.regenDelay or 0
                EntityHelpers.notifyAIDamage(chainTargetId, ownerId)
            end
            if damage2 > 0 then
                local applied2 = math.min(damage2, chainHull.current)
                chainHull.current = chainHull.current - applied2
                EntityHelpers.notifyAIDamage(chainTargetId, ownerId)
                if chainHull.current <= 0 then SkillXP.awardXp("combat") end
            end
            if chainPosComp then chainImpactPos = {x = chainPosComp.x, y = chainPosComp.y} end

        elseif chainAsteroid then
            local durability2 = ECS.getComponent(chainTargetId, "Durability")
            if durability2 then
                -- Chain hits do 1/10th damage to asteroids
                local scaledSecondary = secondaryDamage * 0.1
                local damageApplied2 = math.min(scaledSecondary, durability2.current)
                durability2.current = durability2.current - damageApplied2
                local ownerEntity = ECS.getComponent(ownerId, "ControlledBy")
                if ownerEntity and ownerEntity.pilotId then
                    EntityHelpers.recordLastDamager(chainTargetId, ownerEntity.pilotId, "arc_coil")
                end
                if chainPosComp then
                    chainImpactPos = {x = chainPosComp.x, y = chainPosComp.y}
                    DebrisSystem.createDebris(chainPosComp.x, chainPosComp.y, 1, coilColor)
                end
            end

        elseif chainWreck then
            local durability2 = ECS.getComponent(chainTargetId, "Durability")
            if durability2 then
                -- Chain hits do 1/10th damage to wreckage
                local scaledSecondary = secondaryDamage * 0.1
                local damageApplied2 = math.min(scaledSecondary, durability2.current)
                durability2.current = durability2.current - damageApplied2
                if durability2.current <= 0 then SkillXP.awardXp("salvaging") end
                if chainPosComp then
                    chainImpactPos = {x = chainPosComp.x, y = chainPosComp.y}
                    DebrisSystem.createDebris(chainPosComp.x, chainPosComp.y, 1, coilColor)
                end
            end
        end
    end

    if laserComp then
        laserComp.segments = generateLightningSegments(offsetStartX, offsetStartY, primaryHit.intersection.x, primaryHit.intersection.y)
        if chainImpactPos then
            laserComp.chainSegments = generateLightningSegments(primaryHit.intersection.x, primaryHit.intersection.y, chainImpactPos.x, chainImpactPos.y)
            laserComp.chainColor = chainColor
        else
            laserComp.chainSegments = nil
            laserComp.chainColor = nil
        end
    end

    return {
        hit = true,
        intersection = primaryHit.intersection,
        chainTarget = chainTargetId,
        chainPos = chainImpactPos,
        endPos = beamEnd
    }
end

function ArcCoil.stopFiring(turretComp)
    if turretComp and turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            EntityPool.release("laser_beam", turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
    LaserAudio.stop(turretComp)
end

return ArcCoil
