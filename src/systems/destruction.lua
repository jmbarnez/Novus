-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local WrackageSystem = require('src.systems.wreckage') -- Import WrackageSystem
local ItemDefs = require('src.items.item_loader')

local DestructionSystem = {
    name = "DestructionSystem",
    priority = 6
}

-- Generic function to spawn shatter bits
function DestructionSystem.spawnBits(x, y, params)
    local count = params.count or 8
    local color = params.color or {0.7, 0.7, 0.8, 1}
    local bitType = params.type or "bit"
    local parentSize = params.parentSize or 20
    
    -- Calculate max total size: distribute parent size across all bits
    -- Each bit gets a fraction of the parent size
    local maxBitSize = parentSize / math.sqrt(count) * 0.5  -- Tiny fractions
    local minBitSize = maxBitSize * 0.3
    
    for i = 1, count do
        local angle = math.random() * 2 * math.pi
        local speed = math.random(40, 120)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        local bitSize = minBitSize + math.random() * (maxBitSize - minBitSize)
        
        -- Create a simple square polygon
        local halfSize = bitSize / 2
        local vertices = {
            {x = -halfSize, y = -halfSize},
            {x = halfSize, y = -halfSize},
            {x = halfSize, y = halfSize},
            {x = -halfSize, y = halfSize}
        }
        
        local bitId = ECS.createEntity()
        ECS.addComponent(bitId, "Position", Components.Position(x, y))
        ECS.addComponent(bitId, "Velocity", Components.Velocity(vx, vy))
        ECS.addComponent(bitId, "Physics", Components.Physics(0.98, bitSize*0.3))
        ECS.addComponent(bitId, "PolygonShape", Components.PolygonShape(vertices, math.random()*2*math.pi))
        ECS.addComponent(bitId, "AngularVelocity", Components.AngularVelocity(math.random(-3,3)))
        ECS.addComponent(bitId, "RotationalMass", Components.RotationalMass(bitSize*bitSize*0.1))
        ECS.addComponent(bitId, "Collidable", Components.Collidable(bitSize))
        ECS.addComponent(bitId, "Durability", Components.Durability(bitSize, bitSize))
        ECS.addComponent(bitId, "Renderable", Components.Renderable("polygon", nil, nil, nil, color))
        ECS.addComponent(bitId, "ShatterBit", {type = bitType})
    end
end

function DestructionSystem.update(dt)
    -- Entities to check: any with Durability or Hull
    local entities = ECS.getEntitiesWith({"Durability"})
    local hullEntities = ECS.getEntitiesWith({"Hull"})
    for _, hid in ipairs(hullEntities) do table.insert(entities, hid) end

    for _, entityId in ipairs(entities) do
        local durability = ECS.getComponent(entityId, "Durability")
        local hull = ECS.getComponent(entityId, "Hull")
        local destroyed = false
        if durability and durability.current <= 0 then
            destroyed = true
        elseif hull and hull.current <= 0 then
            destroyed = true
        end
        if destroyed then
            local pos = ECS.getComponent(entityId, "Position")
            local renderable = ECS.getComponent(entityId, "Renderable") -- Get renderable component for color
            local color = renderable and renderable.color or {0.5, 0.5, 0.5, 1} -- Default grey if no color
            
            -- Log if this is a projectile being destroyed
            local proj = ECS.getComponent(entityId, "Projectile")
            if proj then
                print(string.format("[Destruction] Destroying projectile %d", entityId))
            end
            
            -- Check if this is the player's drone - if so, respawn instead of destroying
            local controlledBy = ECS.getComponent(entityId, "ControlledBy")
            if controlledBy and controlledBy.pilotId then
                local pilot = ECS.getComponent(controlledBy.pilotId, "Player")
                if pilot then
                    -- This is the player's drone - respawn it
                    print("[Destruction] Player drone destroyed! Respawning...")
                    DestructionSystem.respawnPlayer(entityId, controlledBy.pilotId)
                    goto continue_entity
                end
            end
            
            -- Call DebrisSystem to create debris particles
            if pos then
                DebrisSystem.createDebris(pos.x, pos.y, nil, color)
                -- Generic shatter: spawn bits if entity requests it
                if durability and durability.spawnBits then
                    DestructionSystem.spawnBits(pos.x, pos.y, durability.spawnBits)
                end
                -- Asteroid: default to stone bits if not specified
                local asteroid = ECS.getComponent(entityId, "Asteroid")
                if asteroid and (not durability or not durability.spawnBits) then
                    local collidable = ECS.getComponent(entityId, "Collidable")
                    local parentSize = collidable and collidable.radius or 20
                    DestructionSystem.spawnBits(pos.x, pos.y, {
                        count = math.random(8, 15),
                        parentSize = parentSize,
                        color = color,  -- Use the actual asteroid color
                        type = "stone"
                    })
                end
            end
            
            -- Check for shatter effect component (for projectiles that break into pieces)
            local shatterEffect = ECS.getComponent(entityId, "ShatterEffect")
            if shatterEffect and pos then
                DebrisSystem.createDebris(pos.x, pos.y, shatterEffect.numPieces, shatterEffect.color)
            end

            -- Determine what type of entity this is for loot drops
            local asteroid = ECS.getComponent(entityId, "Asteroid")
            local hull = ECS.getComponent(entityId, "Hull")
            local aiController = ECS.getComponent(entityId, "AIController")
            local wreckage = ECS.getComponent(entityId, "Wreckage")
            local lootDrop = ECS.getComponent(entityId, "LootDrop")

            -- Spawn loot appropriate to entity type
            if asteroid and pos then
                -- Only spawn loot if killed by player (check for lastDamager component)
                local lastDamager = ECS.getComponent(entityId, "LastDamager")
                if lastDamager and lastDamager.pilotId then
                    -- Check if the damager belongs to the player
                    local pilot = ECS.getComponent(lastDamager.pilotId, "Player")
                    if pilot then
                        DestructionSystem.spawnItemDrops(pos.x, pos.y, "asteroid")
                    end
                end
                -- Otherwise, no drops from enemy mining
            elseif (hull or aiController) and pos then
                DestructionSystem.spawnItemDrops(pos.x, pos.y, "ship")
                -- Spawn wreckage for destroyed ships
                WrackageSystem.spawnWrackage(pos.x, pos.y, "destroyed_ship")
            elseif wreckage and lootDrop and lootDrop.dropsScrap and not lootDrop.droppedScrap and pos then
                -- Wreckage drops scrap (1-2 pieces)
                DestructionSystem.spawnScrapDrop(pos.x, pos.y)
                lootDrop.droppedScrap = true
            end

            ECS.destroyEntity(entityId)
            ::continue_entity::
        end
    end
end

-- Respawn the player's drone at the start position with full hull
function DestructionSystem.respawnPlayer(droneId, pilotId)
    -- Reset drone position to start
    local pos = ECS.getComponent(droneId, "Position")
    if pos then
        pos.x = 0
        pos.y = 0
        pos.prevX = 0
        pos.prevY = 0
    end
    
    -- Reset velocity
    local vel = ECS.getComponent(droneId, "Velocity")
    if vel then
        vel.vx = 0
        vel.vy = 0
    end
    
    -- Restore full hull
    local hull = ECS.getComponent(droneId, "Hull")
    if hull then
        hull.current = hull.max
        print("[Destruction] Player hull restored to full: " .. hull.current .. "/" .. hull.max)
    end
    
    -- Restore shield to full if present
    local shield = ECS.getComponent(droneId, "Shield")
    if shield then
        shield.current = shield.max
        shield.lastDamageTime = 0  -- Reset shield regen timer
    end
    
    print("[Destruction] Player respawned at (0, 0)")
end

-- Spawn item drops around the destruction point
function DestructionSystem.spawnItemDrops(x, y, entityType)
    entityType = entityType or "asteroid"
    
    local itemTypes
    local dropCountMin, dropCountMax
    
    if entityType == "asteroid" then
        itemTypes = {"stone", "iron"}
        dropCountMin, dropCountMax = 2, 4
    elseif entityType == "ship" then
        -- Ships always drop 1-2 scrap
        itemTypes = {"scrap"}
        dropCountMin, dropCountMax = 1, 2
    else
        itemTypes = {"stone", "iron"}
        dropCountMin, dropCountMax = 2, 4
    end
    
    local dropCount = math.random(dropCountMin, dropCountMax)
    
    -- Group items by type for stacking
    local itemsByType = {}
    for i = 1, dropCount do
        local itemType = itemTypes[math.random(#itemTypes)]
        itemsByType[itemType] = (itemsByType[itemType] or 0) + 1
    end
    
    -- Spawn one entity per item type with stack quantity
    for itemType, quantity in pairs(itemsByType) do
        local itemDef = ItemDefs[itemType]
        if itemDef then
            -- Spawn item in random direction around destruction point
            local angle = math.random() * math.pi * 2  -- Random angle 0-2π
            local distance = math.random(70, 120)  -- Distance from center (further to avoid overlap)
            
            local itemX = x + math.cos(angle) * distance
            local itemY = y + math.sin(angle) * distance
            
            -- Random velocity away from destruction point
            local speed = math.random(30, 80)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            
            -- Create item entity
            local itemId = ECS.createEntity()
            ECS.addComponent(itemId, "Position", Components.Position(itemX, itemY))
            ECS.addComponent(itemId, "Velocity", Components.Velocity(vx, vy))
            ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.5))  -- Friction, mass
            ECS.addComponent(itemId, "Item", {id = itemType, def = itemDef})
            ECS.addComponent(itemId, "Stack", Components.Stack(quantity))  -- Add stack with quantity
            ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
        end
    end
end

-- Spawn scrap from destroyed wreckage (1-2 pieces)
function DestructionSystem.spawnScrapDrop(x, y)
    local dropCount = math.random(1, 2)
    
    for i = 1, dropCount do
        local itemDef = ItemDefs["scrap"]
        if itemDef then
            -- Spawn item in random direction around wreckage
            local angle = math.random() * math.pi * 2  -- Random angle 0-2π
            local distance = math.random(30, 60)  -- Distance from wreckage center
            
            local itemX = x + math.cos(angle) * distance
            local itemY = y + math.sin(angle) * distance
            
            -- Random velocity away from wreckage
            local speed = math.random(20, 50)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            
            -- Create item entity
            local itemId = ECS.createEntity()
            ECS.addComponent(itemId, "Position", Components.Position(itemX, itemY))
            ECS.addComponent(itemId, "Velocity", Components.Velocity(vx, vy))
            ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.5))  -- Friction, mass
            ECS.addComponent(itemId, "Item", {id = "scrap", def = itemDef})
            ECS.addComponent(itemId, "Stack", Components.Stack(1))  -- Stack of 1
            ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
        end
    end
end

return DestructionSystem