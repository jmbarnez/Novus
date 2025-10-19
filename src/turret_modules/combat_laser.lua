-- Combat Laser Turret Module
-- Fires a continuous blue laser beam for combat damage

local ECS = require('src.ecs')
local Components = require('src.components')
local CollisionSystem = require('src.systems.collision')
local DebrisSystem = require('src.systems.debris')
local UISystem = require('src.systems.ui')

local CombatLaser = {
    name = "combat_laser",
    LASER_DPS = 35,
    laserEntity = nil  -- Track the current laser beam entity
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
    
    -- Create new laser beam entity
    CombatLaser.laserEntity = ECS.createEntity()
    ECS.addComponent(CombatLaser.laserEntity, "LaserBeam", {
        start = {x = startX, y = startY},
        endPos = {x = endX, y = endY},
        color = {0, 0.8, 1, 1}  -- Blue
    })
    -- Mark this entity as a combat laser projectile for ship damage
    ECS.addComponent(CombatLaser.laserEntity, "Projectile", {ownerId = ownerId, damage = CombatLaser.LASER_DPS, brittle = false, isCombatLaser = true})
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
            local damageApplied = math.min(CombatLaser.LASER_DPS * dt, hull.current)
            hull.current = hull.current - damageApplied
            -- Only grant XP if ship is destroyed this frame
            if hull.current <= 0 then
                UISystem.addSkillExperience("combat", 20)
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
