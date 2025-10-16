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
    local playerEntities = ECS.getEntitiesWith({"InputControlled", "Position"})
    if #playerEntities == 0 then return end
    local playerId = playerEntities[1]
    local playerPos = ECS.getComponent(playerId, "Position")
    local turret = ECS.getComponent(playerId, "Turret")
    if not turret then return end

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
