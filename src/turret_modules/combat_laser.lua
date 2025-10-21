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
    RANGE = math.huge,  -- Unlimited beam range for visual collision
    design = {
        shape = "custom",
        size = 16,
        color = {0, 0.4, 0.5, 1}  -- Half brightness
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.05, 0.075, 0.1, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/3, size, size * 0.6, 3, 3)
        love.graphics.setColor(0, 0.4, 0.5, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(0.1, 0.45, 0.5, 0.9)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        love.graphics.circle("fill", x - size/6, y - size/2.5, size/6)
        love.graphics.setColor(0, 0.3, 0.5, 0.8)
        love.graphics.rectangle("fill", x - size/3, y + size/4, size * 0.65, size/4, 2, 2)
        love.graphics.setColor(0.1, 0.4, 0.5, 0.7)
        love.graphics.rectangle("fill", x - size/3 + 1, y + size/4 + 1, size/3, size/6)
        love.graphics.setColor(0.06, 0.06, 0.075, 0.9)
        love.graphics.line(x - size/2 + 2, y, x - size/2 + 2, y + size/3)
        love.graphics.line(x + size/2 - 2, y, x + size/2 - 2, y + size/3)
    end
}

-- Fire the laser - creates and maintains laser beam entity
function CombatLaser.fire(ownerId, startX, startY, endX, endY, turretComp)
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
    turretComp.laserEntity = ECS.createEntity()
    
    -- Calculate midpoint for position (for depth sorting and rendering order)
    local midX = (offsetStartX + beamEndX) / 2
    local midY = (offsetStartY + beamEndY) / 2
    
    -- Calculate beam length for collision radius
    local dx = beamEndX - offsetStartX
    local dy = beamEndY - offsetStartY
    local beamLength = math.sqrt(dx * dx + dy * dy)
    
    ECS.addComponent(turretComp.laserEntity, "Position", Components.Position(midX, midY))
    -- Add collision component so laser can collide with entities
    ECS.addComponent(turretComp.laserEntity, "Collidable", Components.Collidable(beamLength / 2 + 10))
    ECS.addComponent(turretComp.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = beamEndX, y = beamEndY},
        color = {0, 0.2, 0.25, 1},  -- Dimmed blue laser color (half brightness)
        ownerId = ownerId
    })
    -- Mark this entity as a combat laser projectile for ship damage
    ECS.addComponent(turretComp.laserEntity, "Projectile", {ownerId = ownerId, damage = CombatLaser.DPS, brittle = false, isCombatLaser = true})
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position (ship center)
-- endX, endY: target position (mouse)
-- dt: delta time
-- turretComp: turret component with heat information
function CombatLaser.applyBeam(ownerId, startX, startY, endX, endY, dt, turretComp)
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
        -- Only apply damage if target is a ship (has Hull component)
        local hull = ECS.getComponent(hitEntityId, "Hull")
        if hull then
            -- Calculate distance from laser origin to hit point
            local hitDistance = math.sqrt(closestDistSq)

            -- Distance falloff: damage starts falling off after 300 units, reaches 0 at 800
            local falloffStart = 300
            local falloffEnd = 800
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
                local heatProgress = turretComp.heat / CombatLaser.MAX_HEAT
                heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
            end

            -- Calculate final damage
            local baseDamage = CombatLaser.DPS * dt
            local finalDamage = baseDamage * distanceMultiplier * heatMultiplier

            -- Apply damage to Shield first, then Hull
            local shield = ECS.getComponent(hitEntityId, "Shield")
            local damage = finalDamage

            if shield and shield.current > 0 then
                -- Shield absorbed damage - create impact effect
                local ShieldImpactSystem = ECS.getSystem("ShieldImpactSystem")
                if ShieldImpactSystem and ShieldImpactSystem.createImpact then
                    ShieldImpactSystem.createImpact(closestIntersection.x, closestIntersection.y, hitEntityId)
                end

                local remaining = shield.current - damage
                shield.current = math.max(0, remaining)
                damage = math.max(0, -remaining)
                shield.regenTimer = shield.regenDelay or 0
            end

            if damage > 0 then
                local damageApplied = math.min(damage, hull.current)
                hull.current = hull.current - damageApplied
                print("LASER DAMAGE: Applied " .. damageApplied .. " damage to ship " .. hitEntityId .. ", hull now " .. hull.current)

                -- Only grant XP if ship is destroyed this frame
                if hull.current <= 0 then
                    SkillXP.awardXp("combat")
                end
            end
        end
        -- Store color of hit entity
        local renderable = ECS.getComponent(hitEntityId, "Renderable")
        closestIntersection.color = renderable and renderable.color or {0.5, 0.5, 0.5, 1}
        -- Create impact debris
        DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, closestIntersection.color)
        return {hit = true, intersection = closestIntersection}
    else
        return {hit = false}
    end
end

-- Stop firing - clean up laser beam entity
function CombatLaser.stopFiring(turretComp)
    if turretComp and turretComp.laserEntity then
        local component = ECS.getComponent(turretComp.laserEntity, "LaserBeam")
        if component then
            ECS.destroyEntity(turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
end

return CombatLaser
