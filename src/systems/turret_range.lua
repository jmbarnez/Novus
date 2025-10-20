---@diagnostic disable: undefined-global
-- Turret Range Calculator - Now loads range/cooldown from module definition

local TurretRange = {}

-- Get the maximum firing range for a turret module (pixels)
function TurretRange.getMaxRange(moduleName)
    local ok, module = pcall(function() return require('src.turret_modules.' .. moduleName) end)
    if ok and module and module.RANGE then
        return module.RANGE
    end
    return nil -- No default, module must define
end

-- Get firing delay (cooldown) for a turret (seconds)
function TurretRange.getFireCooldown(moduleName)
    local ok, module = pcall(function() return require('src.turret_modules.' .. moduleName) end)
    if ok and module and module.COOLDOWN then
        return module.COOLDOWN
    end
    return nil -- No default, module must define
end

return TurretRange
