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
        -- Check if it's a laser turret
        local isLaserTurret = turret.moduleName == "mining_laser" or turret.moduleName == "combat_laser" or turret.moduleName == "salvage_laser"
        
        -- If heat is at max (laser turrets only), do not fire and destroy any existing laser
        if isLaserTurret and turret.heat and turret.heat >= (module.MAX_HEAT or 10) then
            -- Destroy the laser entity if it exists to stop invisible firing
            if turret.laserEntity then
                ECS.destroyEntity(turret.laserEntity)
                turret.laserEntity = nil
            end
            return
        end
        if module and module.fire then
            module.fire(entityId, position.x, position.y, targetX, targetY, turret)
            -- accumulate heat using dt if supplied (laser turrets only)
            if isLaserTurret and dt and dt > 0 then
                local heatRate = module.HEAT_RATE or 1.0
                turret.heat = math.min((turret.heat or 0) + heatRate * dt, module.MAX_HEAT or 10)
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
    -- Heat management for continuous laser weapons
    local turretEntities = ECS.getEntitiesWith({"Turret"})
    for _, eid in ipairs(turretEntities) do
        local t = ECS.getComponent(eid, "Turret")
        if not t then goto cont end
        local module = TurretSystem.turretModules[t.moduleName]
        
        -- Only apply heat system to laser turrets
        local isLaserTurret = t.moduleName == "mining_laser" or t.moduleName == "combat_laser" or t.moduleName == "salvage_laser"
        
        if module and module.CONTINUOUS and isLaserTurret then
            -- Check if at max heat (cooldown mode)
            local maxHeat = module.MAX_HEAT or 10
            local isInCooldown = t.heat and t.heat >= maxHeat
            
            if isInCooldown then
                -- In cooldown - track cooldown timer
                t._cooldownTimer = (t._cooldownTimer or 0) + dt
                if t._cooldownTimer >= 2.0 then  -- 2 second cooldown
                    t.heat = 0
                    t._cooldownTimer = 0
                end
            else
                -- Not in cooldown - normal heat management
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
                    -- Cooling down normally
                    local coolRate = module.COOL_RATE or (module.HEAT_RATE or 1.0) * 0.5
                    t.heat = math.max(0, (t.heat or 0) - coolRate * dt)
                end

                -- Track firing state for next frame
                t._wasFiringLastFrame = firedThisFrame
            end
        end
        ::cont::
    end
end

return TurretSystem
