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
-- @param totalSurfaceArea number: Total surface area of the destroyed ship
function WreckageSystem.spawnWreckage(x, y, sourceShip, totalSurfaceArea)
    sourceShip = sourceShip or "unknown"

    -- Total surface area to distribute across wreckage pieces
    totalSurfaceArea = totalSurfaceArea or (math.pi * 16 * 16)  -- Default fallback: circle with radius 16

    -- Estimate number of pieces based on total area (larger ships = more pieces)
    -- Base calculation: sqrt(area) gives approximate radius, divide by ~15-20 for piece count
    local estimatedRadius = math.sqrt(totalSurfaceArea / math.pi)
    local estimated = math.floor(estimatedRadius / 18)
    if estimated < 1 then estimated = 1 end
    local wreckageCount = math.min(5, estimated + math.random(0, 1))  -- Allow up to 5 pieces for large ships

    -- Distribute total area across pieces (with slight random variation)
    -- Calculate area allocation for each piece
    local areaAllocations = {}
    local totalAllocated = 0
    
    -- Generate random proportions that sum to 1.0
    for i = 1, wreckageCount do
        areaAllocations[i] = 0.6 + math.random() * 0.8  -- Random between 0.6 and 1.4
        totalAllocated = totalAllocated + areaAllocations[i]
    end
    
    -- Normalize so they sum to 1.0
    for i = 1, wreckageCount do
        areaAllocations[i] = areaAllocations[i] / totalAllocated
    end

    -- Try to derive a (darker) colour from the original ship design if available
    local shipDesign = ShipLoader.getDesign(sourceShip)

    for i = 1, wreckageCount do
        -- Calculate area for this piece
        local pieceArea = totalSurfaceArea * areaAllocations[i]
        
        -- Convert area to size (radius-like value) for wreckage generation
        -- Wreckage shapes are irregular polygons, approximate area ~= size^2 * scale_factor
        -- For polygons with 4-6 sides, average area is roughly 0.7 * size^2 (empirical estimate)
        local size = math.sqrt(pieceArea / 0.7)

        -- Random spawn position near destruction point (relative to piece size)
        local angle = (math.random() * math.pi * 2)
        local distance = size * (0.8 + math.random() * 1.5)
        local wreckageX = x + math.cos(angle) * distance
        local wreckageY = y + math.sin(angle) * distance

        -- Velocity scales with piece size
        local speed = (10 + math.random() * 40) * (size / 16)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed

        -- Rotation
        local rotationSpeed = (math.random() - 0.5) * math.pi  -- reasonable spin

        local dropsScrap = math.random() < 0.5

        local wreckageId = ECS.createEntity()

        -- Core components
        ECS.addComponent(wreckageId, "Position", Components.Position(wreckageX, wreckageY))
        ECS.addComponent(wreckageId, "Velocity", Components.Velocity(vx, vy))
        ECS.addComponent(wreckageId, "Physics", Components.Physics(0.97, math.max(0.5, size / 8), 0.90))
        ECS.addComponent(wreckageId, "AngularVelocity", Components.AngularVelocity(rotationSpeed))

        -- Wreckage tag
        ECS.addComponent(wreckageId, "Wreckage", Components.Wreckage(sourceShip))

        -- Collision and durability (radius will be updated after scaling)
        -- Give wreckage a durability component with full durability
        local durMax = size * 1.2
        local durabilityComp = Components.Durability(durMax, durMax)
        durabilityComp.current = durMax
        ECS.addComponent(wreckageId, "Durability", durabilityComp)
        -- Wreckage uses Durability (not Hull) so HUD and damage logic remain consistent

        -- Visual: generate jagged shard with exact area matching
        local wreckageVertices = WreckageSystem.generateWreckageShape(size)
        -- Calculate actual area of generated shape
        local actualArea = Components.calculatePolygonArea(wreckageVertices)
        local finalScaleFactor = 1.0
        -- Scale vertices to match target area exactly
        if actualArea > 0 then
            finalScaleFactor = math.sqrt(pieceArea / actualArea)
            for _, v in ipairs(wreckageVertices) do
                v.x = v.x * finalScaleFactor
                v.y = v.y * finalScaleFactor
            end
        end
        
        -- Update collision radius based on final scaled size
        local finalSize = size * finalScaleFactor
        local collRadius = math.max(6, finalSize * 0.6)
        -- Update collision component with correct radius
        ECS.addComponent(wreckageId, "Collidable", Components.Collidable(collRadius))
        
        ECS.addComponent(wreckageId, "PolygonShape", Components.PolygonShape(wreckageVertices, 0))

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
