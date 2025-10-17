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
            position.x = math.max(boundary.minX, math.min(boundary.maxX, position.x))
            position.y = math.max(boundary.minY, math.min(boundary.maxY, position.y))
        end
    end
}

return BoundarySystem