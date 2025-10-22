-- Crystal Formation System
-- Manages small crystal attachments on asteroids that can be mined off

local ECS = require('src.ecs')
local Components = require('src.components')
local DestructionSystem = require('src.systems.destruction')
local ItemDefs = require('src.items.item_loader')
local Constants = require('src.constants')

local CrystalSystem = {
    name = "CrystalFormationSystem",
    priority = 20
}

-- Update attached formations to follow their parent asteroid position & rotation
function CrystalSystem.update(dt)
    local attachedEntities = ECS.getEntitiesWith({"Attached", "Position", "Renderable", "Durability"})
    for _, id in ipairs(attachedEntities) do
        local attached = ECS.getComponent(id, "Attached")
        local pos = ECS.getComponent(id, "Position")
        if not attached or not pos then
            goto continue
        end

        local parentPos = ECS.getComponent(attached.parentId, "Position")
        local parentPoly = ECS.getComponent(attached.parentId, "PolygonShape")
        if not parentPos or not parentPoly then
            -- Parent missing, destroy the attachment
            ECS.destroyEntity(id)
            goto continue
        end

        -- Compute world position from parent's local offset and rotation
        local rot = parentPoly.rotation or 0
        local lx = attached.localX or 0
        local ly = attached.localY or 0
        local cosr = math.cos(rot)
        local sinr = math.sin(rot)
        local wx = parentPos.x + (lx * cosr - ly * sinr)
        local wy = parentPos.y + (lx * sinr + ly * cosr)
        pos.x = wx
        pos.y = wy

        -- If attachment destroyed, spawn crystal items
        local durability = ECS.getComponent(id, "Durability")
        if durability and durability.current and durability.current <= 0 then
            -- Spawn crystal items using DestructionSystem.spawnItems
            DestructionSystem.spawnItems(pos.x or 0, pos.y or 0, {
                count = math.random(1, 3),
                itemType = "crystal",
                distance = 6,
                speed = {30, 80}
            })
            ECS.destroyEntity(id)
        end

        ::continue::
    end
end

return CrystalSystem
