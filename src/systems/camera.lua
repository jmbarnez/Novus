-- Camera System - Handles camera following and viewport management
-- Smoothly follows target entities and manages view transformations

local ECS = require('src.ecs')

local CameraSystem = {
    name = "CameraSystem",

    update = function(dt)
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local targetEntities = ECS.getEntitiesWith({"Position", "CameraTarget"})

        if #cameraEntities > 0 and #targetEntities > 0 then
            local cameraId = cameraEntities[1] -- Assume one camera for now
            local cameraPos = ECS.getComponent(cameraId, "Position")

            -- Find highest priority camera target
            local bestTarget = nil
            local highestPriority = -1

            for _, targetId in ipairs(targetEntities) do
                local target = ECS.getComponent(targetId, "CameraTarget")
                if target.priority > highestPriority then
                    bestTarget = targetId
                    highestPriority = target.priority
                end
            end

            if bestTarget then
                local targetPos = ECS.getComponent(bestTarget, "Position")
                local targetCamera = ECS.getComponent(bestTarget, "CameraTarget")
                local camera = ECS.getComponent(cameraId, "Camera")

                -- Calculate target camera position (centered on player)
                local targetX = targetPos.x - (camera.width / camera.zoom) / 2
                local targetY = targetPos.y - (camera.height / camera.zoom) / 2

                -- Apply smooth camera movement (no physics)
                local smoothing = targetCamera.smoothing or 0.1
                cameraPos.x = cameraPos.x + (targetX - cameraPos.x) * smoothing
                cameraPos.y = cameraPos.y + (targetY - cameraPos.y) * smoothing

                -- Smoothly interpolate zoom towards targetZoom
                local zoomSmoothing = 5 * dt -- Adjust this value for faster/slower zoom
                camera.zoom = camera.zoom + (camera.targetZoom - camera.zoom) * zoomSmoothing
            else
                -- If no target, keep camera at current position (don't move)
                -- This ensures camera stays locked when no target is available
            end
        end
    end,

    -- Apply camera transform for rendering
    applyTransform = function()
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraId = cameraEntities[1]
            local cameraPos = ECS.getComponent(cameraId, "Position")
            local camera = ECS.getComponent(cameraId, "Camera")
            love.graphics.push()
            love.graphics.scale(camera.zoom, camera.zoom)
            love.graphics.translate(-cameraPos.x, -cameraPos.y)
        end
    end,

    -- Reset camera transform
    resetTransform = function()
        love.graphics.pop()
    end
}

return CameraSystem
