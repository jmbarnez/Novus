---@diagnostic disable: undefined-global
-- Camera System - Handles camera following and viewport management
-- Smoothly follows target entities and manages view transformations

local ECS = require('src.ecs')
local CameraUtils = require('src.camera_utils')

-- No zoom steps - smooth continuous zooming

local CameraSystem = {
    name = "CameraSystem",
    priority = 11,
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

                -- Smooth zoom interpolation
                local zoomSmoothing = 0.15 -- Smooth zoom transition speed
                camera.zoom = camera.zoom + (camera.targetZoom - camera.zoom) * zoomSmoothing

                -- Calculate target camera position (centered on player)
                local targetX = targetPos.x - (camera.width / camera.zoom) / 2
                local targetY = targetPos.y - (camera.height / camera.zoom) / 2

                -- Apply smooth camera movement for normal following
                local smoothing = targetCamera.smoothing or 0.1
                cameraPos.x = cameraPos.x + (targetX - cameraPos.x) * smoothing
                cameraPos.y = cameraPos.y + (targetY - cameraPos.y) * smoothing
            else
                -- If no target, keep camera at current position (don't move)
                -- This ensures camera stays locked when no target is available
            end
        end
    end,

    -- Apply camera transform for rendering
    applyTransform = function()
        CameraUtils.applyTransform()
    end,

    -- Reset camera transform
    resetTransform = function()
        CameraUtils.resetTransform()
    end,

    -- Handle resolution changes - re-center camera on target
    onResize = function(screenW, screenH)
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local targetEntities = ECS.getEntitiesWith({"Position", "CameraTarget"})

        if #cameraEntities > 0 and #targetEntities > 0 then
            local cameraId = cameraEntities[1]
            local cameraPos = ECS.getComponent(cameraId, "Position")
            local camera = ECS.getComponent(cameraId, "Camera")

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

            if bestTarget and cameraPos and camera then
                local targetPos = ECS.getComponent(bestTarget, "Position")

                -- Immediately re-center camera on target (no smoothing for resize)
                local targetX = targetPos.x - (camera.width / camera.zoom) / 2
                local targetY = targetPos.y - (camera.height / camera.zoom) / 2

                cameraPos.x = targetX
                cameraPos.y = targetY
            end
        end
    end
}

return CameraSystem
