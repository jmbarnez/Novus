---@diagnostic disable: undefined-global
local Constants = require('src.constants')
local Components = {}

-- InputControlled component - Marks entity as player controllable
-- @field controlType string: Type of control ("drone", "camera", etc.)
-- @field speed number: Movement speed multiplier
-- @field targetedEnemy number: Entity ID of currently targeted enemy (nil if none)
Components.InputControlled = function(controlType, speed)
    return {
        controlType = controlType or "drone",
        speed = speed or Constants.player_max_speed,
        -- targetEntity: optionally references the entity id this controller is piloting
        targetEntity = nil,
        -- targetedEnemy: entity ID of currently targeted enemy ship
        targetedEnemy = nil
    }
end

-- ControlledBy component - Marks an entity as being controlled by a pilot
-- @field pilotId number: Entity ID of the pilot controlling this entity
Components.ControlledBy = function(pilotId)
    return {
        pilotId = pilotId or nil
    }
end

-- CameraTarget component - Marks entity as camera follow target
-- @field priority number: Camera priority (higher = more important)
-- @field smoothing number: Camera smoothing factor (0-1)
Components.CameraTarget = function(priority, smoothing)
    return {
        priority = priority or 1,
        smoothing = smoothing or 0.1
    }
end

-- Camera tag - Marks the camera entity
-- @field width number: The width of the camera viewport
-- @field height number: The height of the camera viewport
-- @field smoothing number: Camera smoothing factor (0-1)
-- @field zoom number: Current zoom level (1.0 = no zoom)
-- @field targetZoom number: The desired zoom level the camera is smoothly approaching
Components.Camera = function(width, height, smoothing, zoom)
    return {
        width = width or 0,
        height = height or 0,
        smoothing = smoothing or 0.1,
        zoom = zoom or 1.0, -- Default zoom level
        targetZoom = zoom or 1.0 -- Initialize targetZoom to current zoom
    }
end

return Components
