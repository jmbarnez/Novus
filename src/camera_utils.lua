---@diagnostic disable: undefined-global
-- Camera Utilities - Stateless camera transformation functions
-- Decouples camera transform operations from CameraSystem

local ECS = require('src.ecs')

local CameraUtils = {}

-- Apply camera transform for rendering
-- Pushes graphics state, applies zoom and translation based on camera entity
function CameraUtils.applyTransform()
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local cameraPos = ECS.getComponent(cameraId, "Position")
        local camera = ECS.getComponent(cameraId, "Camera")
        if camera and cameraPos then
            love.graphics.push()
            love.graphics.scale(camera.zoom, camera.zoom)
            love.graphics.translate(-cameraPos.x, -cameraPos.y)
        end
    end
end

-- Reset camera transform
-- Pops graphics state to restore previous transform
function CameraUtils.resetTransform()
    love.graphics.pop()
end

return CameraUtils
