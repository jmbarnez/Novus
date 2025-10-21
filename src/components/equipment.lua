local Components = {}

-- Turret component - Manages active turret module and firing state
-- @field moduleName string: The name of the currently equipped turret module
-- @field lastFireTime number: The time (love.timer.getTime()) when the turret last fired
-- @field heat table: Heat management (used by heat-generating modules like lasers)
--   @field heat.current number: Current heat level
--   @field heat.cooldownTimer number: Time spent in cooldown
Components.Turret = function(moduleName)
    return {
        moduleName = moduleName or nil, -- No default, must be set by equipping a module
        lastFireTime = -999, -- Initialize to allow first shot immediately
        heat = {
            current = 0,
            cooldownTimer = 0
        }
    }
end

-- TurretSlots component - Holds equipped turret modules
-- @field slots table: Array of turret module names/IDs (max 1 for drone)
Components.TurretSlots = function(maxSlots)
    return {
        slots = {},
        maxSlots = maxSlots or 1
    }
end

-- DefensiveSlots component - Holds equipped defensive modules
-- @field slots table: Array of defensive module names/IDs (max 1 for drone)
Components.DefensiveSlots = function(maxSlots)
    return {
        slots = {},
        maxSlots = maxSlots or 1
    }
end

return Components
