-- Combat Laser Turret Module
-- Fires a continuous blue laser beam for combat damage

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')

local CombatLaser = {
    name = "combat_laser",
    displayName = "Combat Laser",
    CONTINUOUS = true,
    HEAT_RATE = 4.0,
    MAX_HEAT = 12.0,
    COOL_RATE = 3.0,
    DPS = 15,
    RANGE = 800,
    design = {
        shape = "custom",
        size = 16,
        color = {0, 0.8, 1, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.1, 0.15, 0.2, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(0, 0.8, 1, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(0.2, 0.9, 1, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(0, 0.6, 1, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(0.2, 0.8, 1, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        love.graphics.setColor(0.12, 0.12, 0.15, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end,
    laserEntity = nil
}

-- Fire the laser - creates and maintains laser beam entity
function CombatLaser.fire(ownerId, startX, startY, endX, endY)
    -- Destroy old laser if it exists
    if CombatLaser.laserEntity then
        local component = ECS.getComponent(CombatLaser.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(CombatLaser.laserEntity)
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

    -- Limit beam length to maximum range
    local beamEndX = endX
    local beamEndY = endY
    local dx = endX - offsetStartX
    local dy = endY - offsetStartY
    local distToTarget = math.sqrt(dx * dx + dy * dy)
    if distToTarget > CombatLaser.RANGE then
        -- Cap the beam at maximum range
        local ratio = CombatLaser.RANGE / distToTarget
        beamEndX = offsetStartX + dx * ratio
        beamEndY = offsetStartY + dy * ratio
    end

    -- Create new laser beam entity
    CombatLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(CombatLaser.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = beamEndX, y = beamEndY},
        color = {0, 0.8, 1, 1},  -- Blue laser color
    })
    -- Mark this entity as a combat laser projectile for ship damage
    ECS.addComponent(CombatLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = CombatLaser.DPS, brittle = false, isCombatLaser = true})
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function CombatLaser.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitShipId = nil

    -- Check for ship hull hits - look for all entities with Hull component
    local shipEntities = ECS.getEntitiesWith({"Hull", "Position"})
    for _, shipId in ipairs(shipEntities) do
        -- Skip hitting ourselves
        if shipId == ownerId then goto skip_ship end
        
        local polygonShape = ECS.getComponent(shipId, "PolygonShape")
        local intersection = nil
        
        if polygonShape then
            -- Use polygon collision for ships with polygon shapes
            intersection = CollisionSystem.linePolygonIntersect(startX, startY, endX, endY, shipId)
        end
        
        if intersection then
            local distSq = (intersection.x - startX)^2 + (intersection.y - startY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitShipId = shipId
            end
        end
        
        ::skip_ship::
    end

    if closestIntersection and hitShipId then
        -- Apply per-frame DPS to ship hull
        local hull = ECS.getComponent(hitShipId, "Hull")
        if hull then
            -- Calculate distance from laser origin to hit point
            local hitDistance = math.sqrt(closestDistSq)

            -- Distance falloff: damage starts falling off after 400 units, reaches 50% at max range (800)
            local falloffStart = 400
            local falloffEnd = CombatLaser.RANGE
            local distanceMultiplier = 1.0
            if hitDistance > falloffStart then
                local falloffRange = falloffEnd - falloffStart
                local falloffProgress = math.min((hitDistance - falloffStart) / falloffRange, 1.0)
                distanceMultiplier = 1.0 - (falloffProgress * 0.5)  -- Falls to 50% damage
            end

            -- Heat multiplier: damage increases from 1x at 0 heat to 2x at max heat
            local heatMultiplier = 1.0
            if turretComp and turretComp.heat then
                local heatProgress = turretComp.heat / CombatLaser.MAX_HEAT
                heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
            end

            -- Calculate final damage
            local baseDamage = CombatLaser.DPS * dt
            local finalDamage = baseDamage * distanceMultiplier * heatMultiplier
            local damageApplied = math.min(finalDamage, hull.current)
            hull.current = hull.current - damageApplied
            -- Only grant XP if ship is destroyed this frame
            if hull.current <= 0 then
                SkillXP.awardXp("combat")
            end
        end
        -- Store color of hit ship
        local renderable = ECS.getComponent(hitShipId, "Renderable")
        closestIntersection.color = renderable and renderable.color or {0.5, 0.5, 0.5, 1}
        -- Create impact debris
        DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, closestIntersection.color)
        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

-- Stop firing - clean up laser beam entity
function CombatLaser.stopFiring()
    if CombatLaser.laserEntity then
        local component = ECS.getComponent(CombatLaser.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(CombatLaser.laserEntity)
        end
        CombatLaser.laserEntity = nil
    end
end

return CombatLaser
