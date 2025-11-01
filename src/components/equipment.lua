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
        },
        laserSound = nil,
        -- Equipped sub-modules affecting turret behavior (array of item/module tables)
        subModules = {}
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

-- TurretConfig component - per-ship turret settings
-- @field enabled boolean: whether turret is drawn/firing
-- @field scale number: scale multiplier applied to turret size
-- @field overhang number: pixels turret should extend past hull
Components.TurretConfig = function(enabled, scale, overhang)
    return {
        enabled = (enabled == nil) and true or enabled,
        scale = scale or 1.0,
        overhang = overhang or 4
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

-- GeneratorSlots component - Holds equipped generator modules
-- @field slots table: Array of generator module names/IDs (max 1 for drone)
Components.GeneratorSlots = function(maxSlots)
    return {
        slots = {},
        maxSlots = maxSlots or 1
    }
end

-- StatModifiers component - explicit deltas applied by modules/systems
-- Stores additive modifiers applied to the entity's base stats so UI can
-- display exactly what modules changed without guessing.
-- Fields: mass, shield, shieldRegen, energyRegen, hull
Components.StatModifiers = function()
    return {
        mass = 0,
        shield = 0,
        shieldRegen = 0,
        energyRegen = 0,
        hull = 0,
    }
end

return Components
