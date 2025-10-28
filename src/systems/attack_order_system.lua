-- Attack Order System: Processes AttackOrder components set by behavior trees
-- Fires weapons at targets specified in AttackOrder components

local ECS = require('src.ecs')
local TurretRegistry = require('src.turret_registry')
local AiTurretHelper = require('src.systems.ai_turret_helper')

-- Lazy-load TurretSystem to avoid circular dependencies
local TurretSystem

local function getTurretSystem()
    if not TurretSystem then
        TurretSystem = require('src.systems.turret')
    end
    return TurretSystem
end

local AttackOrderSystem = {
    name = "AttackOrderSystem",
    priority = 7  -- Run after behavior trees but before turret system
}

function AttackOrderSystem.update(dt)
    local entities = ECS.getEntitiesWith({"AttackOrder", "Position", "Turret"})
    for _, entityId in ipairs(entities) do
        local attackOrder = ECS.getComponent(entityId, "AttackOrder")
        local pos = ECS.getComponent(entityId, "Position")
        local turret = ECS.getComponent(entityId, "Turret")

        if not (attackOrder and attackOrder.target and pos and turret) then
            goto continue
        end

        -- Get target position
        local targetPos = ECS.getComponent(attackOrder.target, "Position")
        if not targetPos then
            -- Target no longer exists, remove attack order
            ECS.removeComponent(entityId, "AttackOrder")
            goto continue
        end

        -- Check if target is in range
        local dx = targetPos.x - pos.x
        local dy = targetPos.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)

        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule and turretModule.ZERO_DAMAGE_RANGE then
            if dist > turretModule.ZERO_DAMAGE_RANGE then
                -- Target out of range, keep attack order for now (behavior tree will handle)
                goto continue
            end
        end

        -- AI SMART FIRING LOGIC: Use burst patterns for all weapon types
        if not AiTurretHelper.shouldFireThisFrame(entityId, turret, turretModule, dt) then
            goto continue
        end

        -- Aim turret at target
        AiTurretHelper.aimTurretAtTarget(entityId, turret, pos, targetPos)

        -- Fire weapon
        local turretSys = getTurretSystem()
        if turretSys and turretSys.fireTurret then
            turretSys.fireTurret(entityId, targetPos.x, targetPos.y, dt)
        end

        -- Handle continuous beam weapons
        if turretModule and turretModule.CONTINUOUS and turretModule.applyBeam then
            AiTurretHelper.fireLaserAtTarget(entityId, turret, turretModule, targetPos, dt)
        end

        ::continue::
    end
end

return AttackOrderSystem