-- Boundary System - Enforces world boundaries on entities
-- Prevents entities from moving outside the defined world area

local ECS = require('src.ecs')

local BoundarySystem = {
    name = "BoundarySystem",
    priority = 7,
    update = function(dt)
        local entities = ECS.getEntitiesWith({"Position", "Boundary"})

        for _, entityId in ipairs(entities) do
            local position = ECS.getComponent(entityId, "Position")
            local boundary = ECS.getComponent(entityId, "Boundary")

            -- Clamp position to boundary
            local oldX, oldY = position.x, position.y
            local clampedX = math.max(boundary.minX, math.min(boundary.maxX, position.x))
            local clampedY = math.max(boundary.minY, math.min(boundary.maxY, position.y))
            position.x = clampedX
            position.y = clampedY

            -- If entity was clamped on an axis, nudge slightly inside and zero that velocity component
            local nudgew = 1.0 -- small inward nudge (pixels)
            local vel = ECS.getComponent(entityId, "Velocity")
            if oldX ~= clampedX then
                -- Nudge inside depending on which side
                if clampedX <= boundary.minX then
                    position.x = boundary.minX + nudgew
                elseif clampedX >= boundary.maxX then
                    position.x = boundary.maxX - nudgew
                end
                if vel then vel.vx = 0 end
            end
            if oldY ~= clampedY then
                if clampedY <= boundary.minY then
                    position.y = boundary.minY + nudgew
                elseif clampedY >= boundary.maxY then
                    position.y = boundary.maxY - nudgew
                end
                if vel then vel.vy = 0 end
            end
        end
    end
}

return BoundarySystem