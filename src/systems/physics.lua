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

                -- Clamp to max speed
                local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
                if speed > physics.maxSpeed then
                    local scale = physics.maxSpeed / speed
                    velocity.vx = velocity.vx * scale
                    velocity.vy = velocity.vy * scale
                end
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
        end
        
        -- Update angular velocity for entities with rotation
        local angularEntities = ECS.getEntitiesWith({"AngularVelocity", "PolygonShape"})
        for _, entityId in ipairs(angularEntities) do
            local angularVelocity = ECS.getComponent(entityId, "AngularVelocity")
            local polygonShape = ECS.getComponent(entityId, "PolygonShape")
            
            -- Update rotation
            polygonShape.rotation = polygonShape.rotation + angularVelocity.omega * dt
        end
    end,

    takeDamage = function(entityId, amount)
        local health = ECS.getComponent(entityId, "Health")
        if health then
            health.current = math.max(0, health.current - amount)
        end
    end
}

return PhysicsSystem