-- Turret System - Manages turret modules, firing, and cooldowns

local ECS = require('src.ecs')
local Components = require('src.components')

local TurretSystem = {
    name = "TurretSystem",
    turretModules = {} -- Stores loaded turret modules
}

-- Load all turret modules from a directory
function TurretSystem.loadTurretModules(path)
    local files = love.filesystem.getDirectoryItems(path)
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local moduleName = file:match("(.+)%.lua$")
            local fullPath = path .. "." .. moduleName
            local module = require(fullPath)
            TurretSystem.turretModules[moduleName] = module
            print("Loaded turret module: " .. moduleName)
        end
    end
end

function TurretSystem.fireTurret(entityId, targetX, targetY)
    local turret = ECS.getComponent(entityId, "Turret")
    local position = ECS.getComponent(entityId, "Position")
    if not turret or not position then return end

    -- Do nothing if no module is fitted
    if not turret.moduleName or turret.moduleName == "" or turret.moduleName == "default" then
        return
    end

    local currentTime = love.timer.getTime()
    if currentTime - turret.lastFireTime >= turret.cooldown then
        local module = TurretSystem.turretModules[turret.moduleName]
        if module and module.fire then
            module.fire(entityId, position.x, position.y, targetX, targetY)
            turret.lastFireTime = currentTime
        end
    end
end

function TurretSystem.update(dt)
    -- Turret System might have its own update logic for certain turret types later
    -- For now, it primarily responds to explicit fire calls.
end

return TurretSystem
