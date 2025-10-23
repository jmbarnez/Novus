---@diagnostic disable: undefined-global
-- Camera System - Handles camera following and viewport management
-- Smoothly follows target entities and manages view transformations

local ECS = require('src.ecs')

local CAMERA_ZOOM_STEPS = {0.5, 0.75, 1.0, 1.5, 2.0}

local function nearest_zoom_step(value)
    local closest = CAMERA_ZOOM_STEPS[1]
    local min_diff = math.abs(value - closest)
    for i = 2, #CAMERA_ZOOM_STEPS do
        local diff = math.abs(value - CAMERA_ZOOM_STEPS[i])
        if diff < min_diff then
            closest = CAMERA_ZOOM_STEPS[i]
            min_diff = diff
        end
    end
    return closest
end

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

                -- Snap camera.targetZoom to nearest step
                camera.targetZoom = nearest_zoom_step(camera.targetZoom)

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

                -- Snap camera.zoom to the target step when very close
                if math.abs(camera.zoom - camera.targetZoom) < 0.001 then
                    camera.zoom = camera.targetZoom
                end
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
