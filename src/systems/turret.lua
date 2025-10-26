---@diagnostic disable: undefined-global
-- Turret System - Manages turret modules, firing, and cooldowns

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRange = require('src.systems.turret_range')
local TurretRegistry = require('src.turret_registry')

local TurretSystem = {
    name = "TurretSystem",
    turretModules = TurretRegistry.modules -- Backwards compatibility: reference to registry
}

-- Load all turret modules from a directory
function TurretSystem.loadTurretModules(path)
    TurretRegistry.loadModules(path)
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

    local module = TurretRegistry.getModule(turret.moduleName)
    -- If module is continuous (laser), bypass simple cooldown and call fire every frame.
    if module and module.CONTINUOUS then
        -- Check if it's a laser turret
        local isLaserTurret = turret.moduleName == "mining_laser" or turret.moduleName == "combat_laser" or turret.moduleName == "salvage_laser"
        
        if isLaserTurret then
            -- Laser turrets use Heat (stored in turret component)
            if turret.heat and turret.heat.current >= (module.MAX_HEAT or 10) then
                -- At max heat - don't fire
                if module and module.stopFiring then
                    module.stopFiring(turret)
                elseif turret.laserEntity then
                    ECS.destroyEntity(turret.laserEntity)
                    turret.laserEntity = nil
                end
                return
            end
            
            -- Check energy consumption for laser weapons
            local energy = ECS.getComponent(entityId, "Energy")
            local EnergySystem = require('src.systems.energy')
            local energyCost = 0
            
            if turret.moduleName == "mining_laser" then
                energyCost = EnergySystem.CONSUMPTION.mining_laser * dt
            elseif turret.moduleName == "combat_laser" then
                energyCost = EnergySystem.CONSUMPTION.combat_laser * dt
            elseif turret.moduleName == "salvage_laser" then
                energyCost = EnergySystem.CONSUMPTION.salvage_laser * dt
            end
            
            -- Consume energy if firing
            if energy and energyCost > 0 then
                if not EnergySystem.consume(energy, energyCost) then
                    -- Not enough energy - stop firing
                    if module and module.stopFiring then
                        module.stopFiring(turret)
                    elseif turret.laserEntity then
                        ECS.destroyEntity(turret.laserEntity)
                        turret.laserEntity = nil
                    end
                    return
                end
            end
        end
        
        if module and module.fire then
            module.fire(entityId, position.x, position.y, targetX, targetY, turret)
            -- accumulate heat using dt if supplied (laser turrets only)
            if isLaserTurret and dt and dt > 0 then
                if turret.heat then
                    local heatRate = module.HEAT_RATE or 1.0
                    turret.heat.current = math.min((turret.heat.current or 0) + heatRate * dt, module.MAX_HEAT or 10)
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
    -- Heat management for continuous laser weapons
    local turretEntities = ECS.getEntitiesWith({"Turret"})
    for _, entityId in ipairs(turretEntities) do
        local t = ECS.getComponent(entityId, "Turret")
        if not t then goto cont end
        local module = TurretRegistry.getModule(t.moduleName)
        
        -- Only laser turrets should use Heat component, but be safe
        local isLaserTurret = t.moduleName == "mining_laser" or t.moduleName == "combat_laser" or t.moduleName == "salvage_laser"
        
        if module and module.CONTINUOUS and isLaserTurret and t.heat then
            -- Check if at max heat (cooldown mode)
            local maxHeat = module.MAX_HEAT or 10
            local isInCooldown = t.heat.current >= maxHeat
            
            if isInCooldown then
                -- In cooldown - track cooldown timer
                t.heat.cooldownTimer = (t.heat.cooldownTimer or 0) + dt
                if t.heat.cooldownTimer >= 2.0 then  -- 2 second cooldown
                    t.heat.current = 0
                    t.heat.cooldownTimer = 0
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
                    t.heat.current = math.max(0, (t.heat.current or 0) - coolRate * dt)
                end

                -- Track firing state for next frame
                t._wasFiringLastFrame = firedThisFrame
            end
        end
        ::cont::
    end
end

return TurretSystem
