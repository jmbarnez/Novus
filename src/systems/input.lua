-- Input System - Handles player input
-- Translates keyboard and mouse input into entity actions

local ECS = require('src.ecs')
local Constants = require('src.constants')

local InputSystem = {
    name = "InputSystem",

    update = function(dt)
        local entities = ECS.getEntitiesWith({"InputControlled", "Acceleration"})

        for _, entityId in ipairs(entities) do
            local acceleration = ECS.getComponent(entityId, "Acceleration")
            local input = ECS.getComponent(entityId, "InputControlled")

            local new_ax = 0
            local new_ay = 0

            if love.keyboard.isDown("w") then
                new_ay = -input.speed
            end

            if love.keyboard.isDown("s") then
                new_ay = input.speed
            end

            if love.keyboard.isDown("a") then
                new_ax = -input.speed
            end

            if love.keyboard.isDown("d") then
                new_ax = input.speed
            end

            acceleration.ax = new_ax
            acceleration.ay = new_ay
        end
    end
}

function InputSystem.keypressed(key)
    -- Placeholder for key pressed input handling
end

function InputSystem.keyreleased(key)
    -- Placeholder for key released input handling
end

function InputSystem.mousemoved(x, y, dx, dy, isTouch)
    -- This function can be used for other mouse movement related logic if needed.
end

function InputSystem.wheelmoved(x, y)
    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local camera = ECS.getComponent(cameraId, "Camera")
        
        local zoomStep = 0.1 -- How much zoom changes per wheel tick
        
        if y > 0 then -- Mouse wheel up (zoom in)
            camera.targetZoom = math.min(camera.targetZoom + zoomStep, 2.0)
        elseif y < 0 then -- Mouse wheel down (zoom out)
            camera.targetZoom = math.max(camera.targetZoom - zoomStep, 0.5)
        end
    end
end

return InputSystem
