---@diagnostic disable: undefined-global
-- Turret System - Manages turret modules, firing, and cooldowns

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRange = require('src.systems.turret_range')

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

function TurretSystem.fireTurret(entityId, targetX, targetY, dt)
    local turret = ECS.getComponent(entityId, "Turret")
    local position = ECS.getComponent(entityId, "Position")
    if not turret or not position then return end

    -- Do nothing if no module is fitted
    if not turret.moduleName or turret.moduleName == "" or turret.moduleName == "default" then
        -- Turret fire blocked: no module installed
        return
    end

    local module = TurretSystem.turretModules[turret.moduleName]
    -- If module is continuous (laser), bypass simple cooldown and call fire every frame.
    if module and module.CONTINUOUS then
        -- If turret overheated, do not fire and destroy any existing laser
        if turret.overheated then
            -- Destroy the laser entity if it exists to stop invisible firing
            if turret.laserEntity then
                ECS.destroyEntity(turret.laserEntity)
                turret.laserEntity = nil
            end
            return
        end
        if module and module.fire then
            module.fire(entityId, position.x, position.y, targetX, targetY, turret)
            -- accumulate heat using dt if supplied
            if dt and dt > 0 then
                local heatRate = module.HEAT_RATE or 1.0
                turret.heat = math.min((turret.heat or 0) + heatRate * dt, module.MAX_HEAT or 10)
                if turret.heat >= (module.MAX_HEAT or 10) then
                    turret.overheated = true
                end
            end
            turret.lastFireTime = love.timer.getTime()
        end
        return
    end

    -- Non-continuous projectiles use module-defined cooldown
    local moduleCooldown = TurretRange.getFireCooldown(turret.moduleName)
    local currentTime = love.timer.getTime()
    if currentTime - turret.lastFireTime >= moduleCooldown then
        if module and module.fire then
            module.fire(entityId, position.x, position.y, targetX, targetY)
            turret.lastFireTime = currentTime
        end
    end
end

function TurretSystem.update(dt)
    -- Cooldown / heat management for continuous weapons
    local turretEntities = ECS.getEntitiesWith({"Turret"})
    for _, eid in ipairs(turretEntities) do
        local t = ECS.getComponent(eid, "Turret")
        if not t then goto cont end
        local module = TurretSystem.turretModules[t.moduleName]
        if module and module.CONTINUOUS then
            -- Determine if turret is currently firing by checking if it fired THIS frame
            local now = love.timer.getTime()
            local firedThisFrame = (now - (t.lastFireTime or 0)) < dt
            local wasFiring = t._wasFiringLastFrame

            if not firedThisFrame and wasFiring then
                -- Just stopped firing - clean up immediately
                if module.stopFiring then
                    module.stopFiring(t)
                end
            end

            if not firedThisFrame then
                local coolRate = module.COOL_RATE or (module.HEAT_RATE or 1.0) * 0.5
                t.heat = math.max(0, (t.heat or 0) - coolRate * dt)
                -- Recover from overheat when heat drops below 50% of max
                if t.overheated and t.heat < (module.MAX_HEAT or 10) * 0.5 then
                    t.overheated = false
                end
            else
                -- Still firing - if overheat threshold reached, mark overheated (will be destroyed in fireTurret)
                if not t.overheated and t.heat >= (module.MAX_HEAT or 10) then
                    t.overheated = true
                    t.heat = module.MAX_HEAT or 10
                end
            end

            -- Track firing state for next frame
            t._wasFiringLastFrame = firedThisFrame
        end
        ::cont::
    end
end

return TurretSystem
