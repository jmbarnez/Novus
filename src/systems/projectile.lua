-- Projectile System - Handles projectile collisions and effects

local ECS = require('src.ecs')
local Components = require('src.components')

local ProjectileSystem = {
    name = "ProjectileSystem",
    priority = 5
}

function ProjectileSystem.update(dt)
    local projectiles = ECS.getEntitiesWith({"Projectile", "Position", "Collidable"})
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Collidable", "Durability"})
    local wreckages = ECS.getEntitiesWith({"Wreckage", "Position", "Collidable", "Durability"})
    local enemies = ECS.getEntitiesWith({"Hull", "Position", "Collidable"}) -- Enemies have Hull component

    for _, projId in ipairs(projectiles) do
        local projPos = ECS.getComponent(projId, "Position")
        local projColl = ECS.getComponent(projId, "Collidable")
        local projectile = ECS.getComponent(projId, "Projectile")
        if not (projPos and projColl) then goto continue_projectile end

        -- Asteroid damage: only mining lasers
        for _, astId in ipairs(asteroids) do
            local astPos = ECS.getComponent(astId, "Position")
            local astColl = ECS.getComponent(astId, "Collidable")
            if not (astPos and astColl) then goto continue_asteroid end
            local dx = astPos.x - projPos.x
            local dy = astPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = astColl.radius + projColl.radius
            if distSq < radii * radii then
                if projectile and projectile.ownerId == astId then goto continue_asteroid end
                local durability = ECS.getComponent(astId, "Durability")
                if durability and projectile and projectile.isMiningLaser then
                    durability.current = durability.current - (projectile.damage or 10)
                    -- Track who is damaging this asteroid
                    local ownerEntity = ECS.getComponent(projectile.ownerId, "ControlledBy")
                    if ownerEntity and ownerEntity.pilotId then
                        ECS.addComponent(astId, "LastDamager", Components.LastDamager(ownerEntity.pilotId, "mining_laser"))
                    end
                end
                -- If projectile should break on impact, mark its durability to 0 so DestructionSystem handles debris
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                break
            end
            ::continue_asteroid::
        end

        -- Wreckage damage: only salvage lasers
        for _, wreckId in ipairs(wreckages) do
            local wreckPos = ECS.getComponent(wreckId, "Position")
            local wreckColl = ECS.getComponent(wreckId, "Collidable")
            if not (wreckPos and wreckColl) then goto continue_wreckage end
            local dx = wreckPos.x - projPos.x
            local dy = wreckPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = wreckColl.radius + projColl.radius
            if distSq < radii * radii then
                if projectile and projectile.ownerId == wreckId then goto continue_wreckage end
                local durability = ECS.getComponent(wreckId, "Durability")
                if durability and projectile and projectile.isSalvageLaser then
                    durability.current = durability.current - (projectile.damage or 10)
                    -- Track who is damaging this wreckage
                    local ownerEntity = ECS.getComponent(projectile.ownerId, "ControlledBy")
                    if ownerEntity and ownerEntity.pilotId then
                        ECS.addComponent(wreckId, "LastDamager", Components.LastDamager(ownerEntity.pilotId, "salvage_laser"))
                    end
                end
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then projDur.current = 0 end
                end
                break
            end
            ::continue_wreckage::
        end

        -- Enemy damage: all projectiles except mining/salvage lasers hit enemies
        for _, enemyId in ipairs(enemies) do
            if projectile and projectile.ownerId == enemyId then goto continue_enemy end -- Don't hit self
            
            local enemyPos = ECS.getComponent(enemyId, "Position")
            local enemyColl = ECS.getComponent(enemyId, "Collidable")
            if not (enemyPos and enemyColl) then goto continue_enemy end
            
            local dx = enemyPos.x - projPos.x
            local dy = enemyPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = enemyColl.radius + projColl.radius
            
            if distSq < radii * radii then
                -- Only missiles, cannons hit enemies (not mining/salvage lasers)
                if projectile and (projectile.isMissile or projectile.damage) and not projectile.isMiningLaser and not projectile.isSalvageLaser then
                    local hull = ECS.getComponent(enemyId, "Hull")
                    if hull and projectile.damage then
                        hull.current = math.max(0, hull.current - projectile.damage)
                    end
                    
                    -- Destroy missile on impact
                    if projectile.isMissile then
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                    
                    -- Destroy brittle projectiles on impact
                    if projectile.brittle then
                        local projDur = ECS.getComponent(projId, "Durability")
                        if projDur then projDur.current = 0 end
                    end
                end
                break
            end
            ::continue_enemy::
        end

        ::continue_projectile::
    end
end

return ProjectileSystem
