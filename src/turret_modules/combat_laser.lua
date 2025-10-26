-- Combat Laser Turret Module
-- Fires a continuous blue laser beam for combat damage

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local SkillXP = require('src.systems.skill_xp')
local EntityPool = require('src.entity_pool')
local EntityHelpers = require('src.entity_helpers')

local CombatLaser = {
    name = "combat_laser",
    displayName = "Combat Laser",
    CONTINUOUS = true,
    HEAT_RATE = 4.0,
    MAX_HEAT = 12.0,
    COOL_RATE = 3.0,
    DPS = 15,
    RANGE = math.huge,  -- Unlimited beam range for visual collision
    -- Damage falloff configuration
    FALLOFF_START = 300,   -- Full damage up to this distance
    FALLOFF_END = 800,     -- Zero damage beyond this distance
    ZERO_DAMAGE_RANGE = 800,  -- Maximum effective range (beyond this deals no damage)
    design = {
        shape = "custom",
        size = 16,
        color = {0, 0.7, 1, 1}  -- More vibrant cyan blue
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
function CombatLaser.fire(ownerId, startX, startY, endX, endY, turretComp)
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
        local debrisCreated = false
        -- Calculate distance from laser origin to hit point for falloff
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
            local heatProgress = turretComp.heat.current / CombatLaser.MAX_HEAT
            heatMultiplier = 1.0 + (heatProgress * 1.0)  -- Up to 2x damage
        end

        -- Calculate final damage
        local baseDamage = CombatLaser.DPS * dt
        local finalDamage = baseDamage * distanceMultiplier * heatMultiplier

        -- Try to damage ships (Hull component) first
        local hull = ECS.getComponent(hitEntityId, "Hull")
        if hull then
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
            end

            if damage > 0 then
                local damageApplied = math.min(damage, hull.current)
                hull.current = hull.current - damageApplied

                -- Only grant XP if ship is destroyed this frame
                if hull.current <= 0 then
                    SkillXP.awardXp("combat")
                end
            end
            debrisCreated = true
        end

        -- If we didn't create debris via hull/shield logic, still spawn simple impact particles so lasers visibly hit stations/other collidables
        if not debrisCreated then
            DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, CombatLaser.design.color)
        else
            -- Create impact debris with laser beam color for hull hits as well
            DebrisSystem.createDebris(closestIntersection.x, closestIntersection.y, 1, {0, 0.7, 1, 1})
        end

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
            EntityPool.release("laser_beam", turretComp.laserEntity)
        end
        turretComp.laserEntity = nil
    end
end

return CombatLaser
