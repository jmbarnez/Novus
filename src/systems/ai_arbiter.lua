---@diagnostic disable: undefined-global
-- AI Arbiter System
-- Ensures AI ships are tagged with appropriate AI markers (MiningAI/CombatAI)
-- based on their equipped turret module, and corrects AIController state.

local ECS = require('src.ecs')
local Components = require('src.components')

local Arbiter = {
    name = "AIArbiterSystem",
    priority = 8.5 -- Run before AISystem (9) and after EnemyMiningSystem (8) tagging
}

local function isMiningModule(name)
    return name == "mining_laser" or name == "salvage_laser"
end

local function isCombatModule(name)
    return name == "basic_cannon" or name == "combat_laser"
end

function Arbiter.update(dt)
    -- Process all AI-controlled ships
    local aiShips = ECS.getEntitiesWith({"AIController", "Turret"})
    for _, id in ipairs(aiShips) do
        local turret = ECS.getComponent(id, "Turret")
        if turret and turret.moduleName and turret.moduleName ~= "" and turret.moduleName ~= "default" then
            local hasMining = ECS.hasComponent(id, "MiningAI")
            local hasCombat = ECS.hasComponent(id, "CombatAI")

            if isMiningModule(turret.moduleName) then
                if not hasMining then
                    ECS.addComponent(id, "MiningAI", Components.MiningAI())
                end
                if hasCombat then
                    ECS.removeComponent(id, "CombatAI")
                end
                local ai = ECS.getComponent(id, "AIController")
                if ai then ai.state = "mining" end
            elseif isCombatModule(turret.moduleName) then
                if not hasCombat then
                    ECS.addComponent(id, "CombatAI", Components.CombatAI())
                end
                if hasMining then
                    ECS.removeComponent(id, "MiningAI")
                end
            end
        end
    end
end

return Arbiter
