---@diagnostic disable: undefined-global
-- Wreckage System - Handles creation and management of salvageable wreckage

local ECS = require('src.ecs')
local Components = require('src.components')
local ShipLoader = require('src.ship_loader')

local WreckageSystem = {
    name = "WreckageSystem",
    priority = 7
}

-- Spawn wreckage pieces around a destroyed ship
-- @param x number: X position of ship destruction
-- @param y number: Y position of ship destruction
-- @param sourceShip string: Identifier for the source ship type
function WreckageSystem.spawnWreckage(x, y, sourceShip, parentRadius)
    sourceShip = sourceShip or "unknown"

    -- Parent size influences number and size of wreckage pieces.
    parentRadius = parentRadius or 16

    -- Estimate few pieces based on parent radius (clamped to 1-3)
    local estimated = math.floor(parentRadius / 20)
    if estimated < 1 then estimated = 1 end
    local wreckageCount = math.min(3, estimated + math.random(0, 1))

    -- Try to derive a (darker) colour and size info from the original ship design if available
    local shipDesign = ShipLoader.getDesign(sourceShip)
    
    -- Get base size from ship design if available, otherwise use parentRadius
    local baseSize = parentRadius
    if shipDesign and shipDesign.size then
        -- Use ship design size as reference, but scale by parentRadius if provided
        baseSize = math.max(parentRadius, shipDesign.size * 0.8)
    end

    for i = 1, wreckageCount do
        -- Size scales with parent ship size, add slight randomness
        -- Make pieces proportionally larger: 0.6x to 1.0x of base size (was 0.5x to 1.3x)
        local size = baseSize * (0.6 + math.random() * 0.4)

        -- Random spawn position near destruction point (relative to parent size)
        local angle = (math.random() * math.pi * 2)
        local distance = parentRadius * (0.6 + math.random() * 1.2)
        local wreckageX = x + math.cos(angle) * distance
        local wreckageY = y + math.sin(angle) * distance

        -- Velocity scales with parent size
        local speed = (10 + math.random() * 40) * (parentRadius / 16)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed

        -- Rotation
        local rotationSpeed = (math.random() - 0.5) * math.pi  -- reasonable spin

        local dropsScrap = math.random() < 0.5

        local wreckageId = ECS.createEntity()

        -- Core components
        ECS.addComponent(wreckageId, "Position", Components.Position(wreckageX, wreckageY))
        ECS.addComponent(wreckageId, "Velocity", Components.Velocity(vx, vy))
        ECS.addComponent(wreckageId, "Physics", Components.Physics(0.97, math.max(0.5, parentRadius / 8), 0.90))
        ECS.addComponent(wreckageId, "AngularVelocity", Components.AngularVelocity(rotationSpeed))

        -- Wreckage tag
        ECS.addComponent(wreckageId, "Wreckage", Components.Wreckage(sourceShip))

        -- Collision and durability
        local collRadius = math.max(6, size * 0.6)
        ECS.addComponent(wreckageId, "Collidable", Components.Collidable(collRadius))
        ECS.addComponent(wreckageId, "Durability", Components.Durability(size * 1.2, size * 1.2))
        -- Treat wreckage as hull so damage/targeting logic is consistent with ships
        ECS.addComponent(wreckageId, "Hull", Components.Hull(math.floor(size * 1.2), math.floor(size * 1.2)))

        -- Visual: generate jagged shard scaled by size
        ECS.addComponent(wreckageId, "PolygonShape", Components.PolygonShape(WreckageSystem.generateWreckageShape(size), 0))

        -- Determine wreckage color: prefer ship design but darken it
        local baseColor = {0.4, 0.4, 0.45, 1}
        if shipDesign then
            if shipDesign.colors and shipDesign.colors.stripes then
                local s = shipDesign.colors.stripes
                baseColor = {s[1] * 0.6, s[2] * 0.6, s[3] * 0.6, s[4] or 1}
            elseif shipDesign.color and shipDesign.color[1] then
                local s = shipDesign.color
                baseColor = {s[1] * 0.6, s[2] * 0.6, s[3] * 0.6, s[4] or 1}
            end
        end

        ECS.addComponent(wreckageId, "Renderable", Components.Renderable("polygon", nil, nil, nil, baseColor))

        -- Loot drop
        ECS.addComponent(wreckageId, "LootDrop", {dropsScrap = dropsScrap, droppedScrap = false})
    end
end

-- Generate a random angular polygon shape for wreckage
function WreckageSystem.generateWreckageShape(size)
    local vertices = {}
    local sides = math.random(4, 6)
    
    for i = 1, sides do
        local angle = (i / sides) * math.pi * 2
        local distance = size * (0.7 + math.random() * 0.3)  -- Slight randomness in distance
        table.insert(vertices, {x = math.cos(angle) * distance, y = math.sin(angle) * distance})
    end
    
    return vertices
end

return WreckageSystem
