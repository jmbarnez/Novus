---@diagnostic disable: undefined-global
-- Mining System - Handles the player's mining laser

local ECS = require('src.ecs')
local Components = require('src.components')
local TurretSystem = require('src.systems.turret')
local ItemDefs = require('src.items.item_loader')

local MiningSystem = {
    name = "MiningSystem",
    laserEntity = nil
}

function MiningSystem.update(dt)
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local playerId = input.targetEntity
    local playerPos = ECS.getComponent(playerId, "Position")
    local turret = ECS.getComponent(playerId, "Turret")
    if not turret then return end

    -- Prevent mining if no module is fitted
    if not turret.moduleName or turret.moduleName == "" or turret.moduleName == "default" then
        if MiningSystem.laserEntity then
            ECS.destroyEntity(MiningSystem.laserEntity)
            MiningSystem.laserEntity = nil
        end
        return
    end

    -- Always get the equipped turret module from TurretSystem
    local turretModules = TurretSystem.turretModules
    local turretModule = turretModules[turret.moduleName]
    if not turretModule or not turretModule.applyBeam then return end

    if love.mouse.isDown(1) then -- Left mouse button held
        -- ...existing code...
    elseif MiningSystem.laserEntity then
        ECS.destroyEntity(MiningSystem.laserEntity)
        MiningSystem.laserEntity = nil
    end
end

return MiningSystem
