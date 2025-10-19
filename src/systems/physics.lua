-- Physics System - Handles all physics-related calculations
-- Updates entity positions based on velocity and acceleration

local ECS = require('src.ecs')

local PhysicsSystem = {
    name = "PhysicsSystem",
    priority = 2,

    update = function(dt)
        -- Get all entities with Position and Velocity (physics applies to all moving entities)
        local entities = ECS.getEntitiesWith({"Position", "Velocity"})

        for _, entityId in ipairs(entities) do
            local position = ECS.getComponent(entityId, "Position")
            local velocity = ECS.getComponent(entityId, "Velocity")
            if not (position and velocity) then goto continue_entity end
            local physics = ECS.getComponent(entityId, "Physics")
            local acceleration = ECS.getComponent(entityId, "Acceleration")

            -- Store previous position for CCD (Continuous Collision Detection)
            position.prevX = position.x
            position.prevY = position.y
            
            -- Store previous rotation for rotated object CCD
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            if polygonShape then
                polygonShape.prevRotation = polygonShape.rotation
            end

            -- Apply acceleration to velocity
            if acceleration then
                velocity.vx = velocity.vx + acceleration.ax * dt
                velocity.vy = velocity.vy + acceleration.ay * dt
            end

            -- Apply friction (use default values if no Physics component)
            if physics then
                velocity.vx = velocity.vx * physics.friction
                velocity.vy = velocity.vy * physics.friction
            end

            -- Update position based on velocity
            position.x = position.x + velocity.vx * dt
            position.y = position.y + velocity.vy * dt
            
            -- Debug log for projectiles
            local proj = ECS.getComponent(entityId, "Projectile")
            if proj and velocity then
                if velocity.vx ~= 0 or velocity.vy ~= 0 then
                    print(string.format("[PhysicsSystem] Projectile %d moved to (%.2f, %.2f)", entityId, position.x, position.y))
                end
            end
            ::continue_entity::
        end
        
        -- Update angular velocity for entities with rotation
        local angularEntities = ECS.getEntitiesWith({"AngularVelocity", "PolygonShape"})
        for _, entityId in ipairs(angularEntities) do
            local angularVelocity = ECS.getComponent(entityId, "AngularVelocity")
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            if not (angularVelocity and polygonShape) then goto continue_angular end
            -- Update rotation
            polygonShape.rotation = polygonShape.rotation + (angularVelocity.omega or 0) * dt
            ::continue_angular::
        end

        -- Shield regeneration (per-entity)
        local shieldEntities = ECS.getEntitiesWith({"Shield"})
        for _, entityId in ipairs(shieldEntities) do
            local shield = ECS.getComponent(entityId, "Shield")
            if not shield then goto continue_shield end
            -- Count down regen delay
            if shield.regenTimer and shield.regenTimer > 0 then
                shield.regenTimer = shield.regenTimer - dt
            else
                if shield.regen and shield.regen > 0 and shield.current < shield.max then
                    shield.current = math.min(shield.max, shield.current + shield.regen * dt)
                end
            end
            ::continue_shield::
        end
    end,

    takeDamage = function(entityId, amount)
        -- Apply damage to shield first, then hull
        local shield = ECS.getComponent(entityId, "Shield")
        local hull = ECS.getComponent(entityId, "Hull")
        local damage = amount
        if shield and shield.current > 0 then
            local remaining = shield.current - damage
            shield.current = math.max(0, remaining)
            damage = math.max(0, -remaining)
            shield.regenTimer = shield.regenDelay or 0
        end
        if damage > 0 and hull then
            hull.current = math.max(0, hull.current - damage)
        end
    end
}

return PhysicsSystem