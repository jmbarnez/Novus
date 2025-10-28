---@diagnostic disable: undefined-global
-- AI Turret Helper - Consolidated turret firing logic for AI
-- Removes duplication and provides clean firing interface

local ECS = require('src.ecs')

local AiTurretHelper = {}

-- Estimate base radius from entity components (collidable, polygon vertices, or renderable circle)
local function estimateBaseRadiusFromEntity(eid)
    if eid then
        local collidable = ECS.getComponent(eid, "Collidable")
        if collidable and collidable.radius then return collidable.radius end
        local polygon = ECS.getComponent(eid, "PolygonShape")
        if polygon and polygon.vertices then
            local r = 0
            for _, v in ipairs(polygon.vertices) do
                local dx = (v.x or 0)
                local dy = (v.y or 0)
                local d = math.sqrt(dx*dx + dy*dy)
                if d > r then r = d end
            end
            if r > 0 then return r end
        end
        local renderable = ECS.getComponent(eid, "Renderable")
        if renderable and renderable.radius then return renderable.radius end
    end
    return 12
end

local function computeMuzzleDistance(eid)
    local base = estimateBaseRadiusFromEntity(eid)
    -- Allow per-ship turret overrides
    local overhang = 4
    local scaleMult = 1.0
    if eid then
        local cfg = ECS.getComponent(eid, "TurretConfig")
        if cfg then
            if cfg.overhang then overhang = cfg.overhang end
            if cfg.scale then scaleMult = cfg.scale end
        end
    end
    return math.max(10, math.floor(base * 0.9 * scaleMult) + overhang)
end

-- Calculate damage multiplier based on laser falloff distance
-- Returns a value from 0.0 to 1.0 representing damage effectiveness at that distance
-- @param turretModule: The turret module with FALLOFF_START and FALLOFF_END
-- @param distance: Current distance to target
-- @return damageMultiplier (0.0 to 1.0)
function AiTurretHelper.calculateDamageMultiplier(turretModule, distance)
    if not turretModule or not turretModule.CONTINUOUS then
        return 1.0  -- Non-continuous weapons always deal full damage
    end
    
    if not turretModule.FALLOFF_START or not turretModule.FALLOFF_END then
        return 1.0  -- No falloff defined, assume full damage
    end
    
    -- If within full damage range, return 1.0
    if distance <= turretModule.FALLOFF_START then
        return 1.0
    end
    
    -- If beyond falloff end, return 0
    if distance >= turretModule.FALLOFF_END then
        return 0.0
    end
    
    -- Linear interpolation between falloff start and end
    local falloffRange = turretModule.FALLOFF_END - turretModule.FALLOFF_START
    local falloffProgress = (distance - turretModule.FALLOFF_START) / falloffRange
    return 1.0 - falloffProgress
end

-- Check if a turret can meaningfully fire at this distance
-- @param turretModule: The turret module
-- @param distance: Current distance to target
-- @param minEffectiveness: Minimum damage multiplier to consider firing (default 0.1)
-- @return canFire (boolean)
function AiTurretHelper.canFireAtDistance(turretModule, distance, minEffectiveness)
    minEffectiveness = minEffectiveness or 0.1
    local multiplier = AiTurretHelper.calculateDamageMultiplier(turretModule, distance)
    return multiplier >= minEffectiveness
end

-- Get the effective engagement range for a turret module
-- This is the distance at which damage falls to minEffectiveness
-- @param turretModule: The turret module
-- @param minEffectiveness: Minimum damage multiplier threshold (default 0.1)
-- @return engagementRange (pixels)
function AiTurretHelper.getEffectiveEngagementRange(turretModule, minEffectiveness)
    minEffectiveness = minEffectiveness or 0.1
    
    -- For non-continuous weapons, use a default range
    if not turretModule or not turretModule.CONTINUOUS then
        return 1000
    end
    
    -- For lasers, calculate from falloff config
    if turretModule.FALLOFF_END then
        return turretModule.FALLOFF_END
    end
    
    return 1000  -- Fallback
end

-- Fire a laser turret with proper positioning and damage handling
-- Consolidated logic from chase/orbit states to reduce duplication
-- @param eid: Entity ID of the shooter
-- @param turret: Turret component
-- @param turretModule: Turret module definition
-- @param targetPos: Table with x, y coordinates of target
-- @param dt: Delta time
-- @return fireSuccessful (boolean)
function AiTurretHelper.fireLaserAtTarget(eid, turret, turretModule, targetPos, dt)
    if not turret or not turretModule or not turretModule.fire then
        return false
    end
    
    local pos = ECS.getComponent(eid, "Position")
    if not pos then
        return false
    end
    
    local dx = targetPos.x - pos.x
    local dy = targetPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist == 0 then
        return false
    end
    
    -- Check if laser can fire (not overheated)
    local canFire = true
    if turret.heat then
        canFire = turret.heat.current < (turretModule.MAX_HEAT or 10)
    end
    
    if not canFire then
        return false
    end
    
    -- Check energy before firing (energy already consumed by TurretSystem.fireTurret)
    -- Just verify that energy is available, don't consume again
    local energyPerSecond = turretModule.ENERGY_PER_SECOND
    local EnergySystem = require('src.systems.energy')
    if not energyPerSecond and EnergySystem and EnergySystem.CONSUMPTION then
        energyPerSecond = EnergySystem.CONSUMPTION[turret.moduleName]
    end
    if energyPerSecond and dt and dt > 0 then
        local energy = ECS.getComponent(eid, "Energy")
        if energy and energy.current < energyPerSecond * dt then
            return false
        end
    end
    
    -- Check if damage at this distance is meaningful
    if not AiTurretHelper.canFireAtDistance(turretModule, dist) then
        return false
    end
    
    -- Calculate laser start position from barrel
    local fireAngle = math.atan2(dy, dx)
    local muzzleDistance = computeMuzzleDistance(eid)
    
    -- Calculate final muzzle position (ship center + collider radius + muzzle distance)
    local collider = ECS.getComponent(eid, "Collidable")
    local totalDistance = muzzleDistance
    if collider then
        totalDistance = collider.radius + muzzleDistance
    end
    
    local laserStartX = pos.x + math.cos(fireAngle) * totalDistance
    local laserStartY = pos.y + math.sin(fireAngle) * totalDistance
    
    -- Call the module's fire() function directly to create laser entity
    if turretModule.fire then
        turretModule.fire(eid, laserStartX, laserStartY, targetPos.x, targetPos.y, turret)
    end
    
    -- Apply damage and get collision result
    if turretModule.applyBeam then
        local beamResult = turretModule.applyBeam(eid, laserStartX, laserStartY, targetPos.x, targetPos.y, dt, turret)
        
        -- Update laser beam visual endpoint based on collision
        if turret.laserEntity then
            local laserBeam = ECS.getComponent(turret.laserEntity, "LaserBeam")
            if laserBeam then
                laserBeam.start = {x = laserStartX, y = laserStartY}
                -- Use collision point if hit, otherwise use target position
                if beamResult and beamResult.hit and beamResult.intersection then
                    laserBeam.endPos = {x = beamResult.intersection.x, y = beamResult.intersection.y}
                else
                    laserBeam.endPos = {x = targetPos.x, y = targetPos.y}
                end
            end
        end
    else
        -- For non-continuous weapons, just update the visual endpoint
        if turret.laserEntity then
            local laserBeam = ECS.getComponent(turret.laserEntity, "LaserBeam")
            if laserBeam then
                laserBeam.start = {x = laserStartX, y = laserStartY}
                laserBeam.endPos = {x = targetPos.x, y = targetPos.y}
            end
        end
    end
    
    return true
end

-- Setup turret aiming position for rendering
-- @param turret: Turret component
-- @param shooterPos: Table with x, y of shooter
-- @param targetPos: Table with x, y of target
function AiTurretHelper.aimTurretAtTarget(eid, turret, shooterPos, targetPos)
    -- Explicit signature: aimTurretAtTarget(eid, turret, shooterPos, targetPos)
    if not eid or not turret or not shooterPos or not targetPos then return end
    local dx = targetPos.x - shooterPos.x
    local dy = targetPos.y - shooterPos.y
    local fireAngle = math.atan2(dy, dx)
    local muzzleDistance = computeMuzzleDistance(eid)
    
    -- Calculate final muzzle position (ship center + collider radius + muzzle distance)
    local collider = ECS.getComponent(eid, "Collidable")
    local totalDistance = muzzleDistance
    if collider then
        totalDistance = collider.radius + muzzleDistance
    end
    
    turret.aimX = shooterPos.x + math.cos(fireAngle) * totalDistance
    turret.aimY = shooterPos.y + math.sin(fireAngle) * totalDistance
end

return AiTurretHelper
