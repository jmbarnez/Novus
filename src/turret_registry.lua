---@diagnostic disable: undefined-global
-- Turret Registry - Central registry for turret modules
-- Decouples turret module access from TurretSystem

local TurretRegistry = {
    modules = {} -- Stores loaded turret modules
}

-- Load all turret modules from a directory
function TurretRegistry.loadModules(path)
    local files = love.filesystem.getDirectoryItems(path)
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local moduleName = file:match("(.+)%.lua$")
            local fullPath = path .. "." .. moduleName
            local module = require(fullPath)
            TurretRegistry.modules[moduleName] = module
        end
    end
end

-- Get a turret module by name
-- @param moduleName string: Name of the turret module
-- @return table: The turret module, or nil if not found
function TurretRegistry.getModule(moduleName)
    return TurretRegistry.modules[moduleName]
end

-- Check if a turret module exists
-- @param moduleName string: Name of the turret module
-- @return boolean: True if module exists
function TurretRegistry.hasModule(moduleName)
    return TurretRegistry.modules[moduleName] ~= nil
end

return TurretRegistry
