---@diagnostic disable: undefined-global
-- Turret Range Calculator - Now loads range/cooldown from module definition

local TurretRange = {}

-- Get the maximum firing range for a turret module (pixels)
function TurretRange.getMaxRange(moduleName)
    local ok, module = pcall(function() return require('src.turret_modules.' .. moduleName) end)
    if ok and module and module.RANGE then
        return module.RANGE
    end
    return 500 -- Default range if not specified by module
end

-- Get firing delay (cooldown) for a turret (seconds)
function TurretRange.getFireCooldown(moduleName)
    local ok, module = pcall(function() return require('src.turret_modules.' .. moduleName) end)
    if ok and module and module.COOLDOWN then
        return module.COOLDOWN
    end
    -- If module not found or COOLDOWN missing, fallback to default cooldown
    return 0.7 -- Default cooldown if not specified by module
end

return TurretRange
