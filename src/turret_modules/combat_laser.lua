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
    COOLDOWN = 6,
    DPS = 35,
    RANGE = 1600,
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
    
    -- Create new laser beam entity
    CombatLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(CombatLaser.laserEntity, "LaserBeam", {
        start = {x = offsetStartX, y = offsetStartY},
        endPos = {x = endX, y = endY},
        color = CombatLaser.design.beamColor,
    })
    -- Mark this entity as a combat laser projectile for ship damage
    ECS.addComponent(CombatLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = CombatLaser.DPS, brittle = false, isCombatLaser = true})
end

-- Called every frame while the laser is firing
-- startX, startY: muzzle position
-- endX, endY: target position (mouse)
-- dt: delta time
function CombatLaser.applyBeam(ownerId, startX, startY, endX, endY, dt)
    local closestIntersection = nil
    local closestDistSq = math.huge
    local hitShipId = nil

    -- Check for ship hull hits
    local shipEntities = ECS.getEntitiesWith({"Hull", "Collidable", "Position", "PolygonShape"})
    for _, shipId in ipairs(shipEntities) do
        local intersection = CollisionSystem.linePolygonIntersect(startX, startY, endX, endY, shipId)
        if intersection then
            local distSq = (intersection.x - startX)^2 + (intersection.y - startY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                closestIntersection = intersection
                hitShipId = shipId
            end
        end
    end

    if closestIntersection and hitShipId then
        -- Apply per-frame DPS to ship hull
        local hull = ECS.getComponent(hitShipId, "Hull")
        if hull then
            local damageApplied = math.min(CombatLaser.DPS * dt, hull.current)
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

return CombatLaser
