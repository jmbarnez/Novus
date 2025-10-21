local Components = {}

-- Turret component - Manages active turret module and firing state
-- @field moduleName string: The name of the currently equipped turret module
-- @field cooldown number: The cooldown duration in seconds (now read from module)
-- @field lastFireTime number: The time (love.timer.getTime()) when the turret last fired
Components.Turret = function(moduleName)
    return {
        moduleName = moduleName or nil, -- No default, must be set by equipping a module
        lastFireTime = -999, -- Initialize to allow first shot immediately
        heat = 0, -- Current heat for continuous weapons (lasers)
        overheated = false -- Whether the turret is currently overheated
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
