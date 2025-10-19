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

    for _, projId in ipairs(projectiles) do
        local projPos = ECS.getComponent(projId, "Position")
        local projColl = ECS.getComponent(projId, "Collidable")
        local projectile = ECS.getComponent(projId, "Projectile")

        if not (projPos and projColl) then
            -- Missing necessary components; skip
            goto continue_projectile
        end

        for _, astId in ipairs(asteroids) do
            local astPos = ECS.getComponent(astId, "Position")
            local astColl = ECS.getComponent(astId, "Collidable")
            if not (astPos and astColl) then
                goto continue_asteroid
            end

            -- Broad-phase collision check
            local dx = astPos.x - projPos.x
            local dy = astPos.y - projPos.y
            local distSq = dx * dx + dy * dy
            local radii = astColl.radius + projColl.radius
            
            if distSq < radii * radii then
                    -- Ignore collision if asteroid is the owner of the projectile
                    if projectile and projectile.ownerId == astId then
                        goto continue_asteroid
                    end
                -- Collision detected
                local durability = ECS.getComponent(astId, "Durability")
                if durability and projectile then
                    -- Only allow mining laser projectiles to damage asteroids
                    if projectile.isMiningLaser then
                        durability.current = durability.current - (projectile.damage or 10)
                    else
                        -- Regular projectiles from player cannons also damage asteroids
                        durability.current = durability.current - (projectile.damage or 10)
                        
                        -- Track who is damaging this asteroid
                        local ownerEntity = ECS.getComponent(projectile.ownerId, "ControlledBy")
                        if ownerEntity and ownerEntity.pilotId then
                            ECS.addComponent(astId, "LastDamager", Components.LastDamager(ownerEntity.pilotId, "cannon"))
                        end
                    end
                end
                
                -- Previously we destroyed the projectile immediately.
                -- Now allow the PhysicsCollisionSystem to handle physical response and durability-based destruction.
                -- Apply immediate damage to asteroid here as well so there's no delay for non-physics objects.
                -- No extra damage here; it's handled safely above when projectile exists

                -- If projectile should break on impact, mark its durability to 0 so DestructionSystem handles debris
                if projectile and projectile.brittle then
                    local projDur = ECS.getComponent(projId, "Durability")
                    if projDur then
                        projDur.current = 0
                    end
                end
                -- Stop checking this projectile for now
                break
            end
            ::continue_asteroid::
        end
        ::continue_projectile::
    end
end

return ProjectileSystem
