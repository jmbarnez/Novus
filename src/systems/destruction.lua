-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local WrackageSystem = require('src.systems.wreckage') -- Import WrackageSystem
local ItemDefs = require('src.items.item_loader')

local DestructionSystem = {
    name = "DestructionSystem",
    priority = 6
}

-- Unified function to spawn item drops from destroyed entities
-- params: { count, itemType, distance, speed, stackItems } or simple values
function DestructionSystem.spawnItems(x, y, params)
    params = params or {}
    
    local count = params.count or 1
    local itemType = params.itemType or "stone"
    local distance = params.distance or 0  -- 0 = spawn at center, otherwise random distance
    local speed = params.speed  -- speed range: {min, max} or single value
    local stackItems = params.stackItems or false  -- if true, group items into stacks
    
    -- Default speed ranges based on context
    if not speed then
        speed = {Constants.bit_spawn_speed_asteroid_min or 40, Constants.bit_spawn_speed_asteroid_max or 120}
    elseif type(speed) == "number" then
        speed = {speed, speed}
    end
    
    if stackItems then
        -- Group items by type and create stacked items
        local itemsByType = {}
        for i = 1, count do
            local type_ = itemType
            if type(itemType) == "table" then
                type_ = itemType[math.random(#itemType)]
            end
            itemsByType[type_] = (itemsByType[type_] or 0) + 1
        end
        
        for type_, quantity in pairs(itemsByType) do
            local itemDef = ItemDefs[type_]
            if itemDef then
                local angle = math.random() * 2 * math.pi
                local dist = distance > 0 and math.random(distance * 0.5, distance) or 0
                local itemX = x + math.cos(angle) * dist
                local itemY = y + math.sin(angle) * dist
                
                local spd = speed[1] + math.random() * (speed[2] - speed[1])
                local vx = math.cos(angle) * spd
                local vy = math.sin(angle) * spd
                
                local itemId = ECS.createEntity()
                ECS.addComponent(itemId, "Position", Components.Position(itemX, itemY))
                ECS.addComponent(itemId, "Velocity", Components.Velocity(vx, vy))
                ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.5))
                ECS.addComponent(itemId, "Item", {id = type_, def = itemDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(quantity))
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
            end
        end
    else
        -- Spawn individual items
        for i = 1, count do
            local type_ = itemType
            if type(itemType) == "table" then
                type_ = itemType[math.random(#itemType)]
            end
            
            local itemDef = ItemDefs[type_]
            if itemDef then
                local angle = math.random() * 2 * math.pi
                local dist = distance > 0 and math.random(distance * 0.5, distance) or 0
                local itemX = x + math.cos(angle) * dist
                local itemY = y + math.sin(angle) * dist
                
                local spd = speed[1] + math.random() * (speed[2] - speed[1])
                local vx = math.cos(angle) * spd
                local vy = math.sin(angle) * spd
                
                local itemId = ECS.createEntity()
                ECS.addComponent(itemId, "Position", Components.Position(itemX, itemY))
                ECS.addComponent(itemId, "Velocity", Components.Velocity(vx, vy))
                ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.5))
                ECS.addComponent(itemId, "Item", {id = type_, def = itemDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(1))
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
            end
        end
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
                -- Spawn items if entity requests it
                if durability and durability.spawnBits then
                    DestructionSystem.spawnItems(pos.x, pos.y, durability.spawnBits)
                end
                -- Asteroid: drop items based on asteroid type
                local asteroid = ECS.getComponent(entityId, "Asteroid")
                if asteroid and (not durability or not durability.spawnBits) then
                    local collidable = ECS.getComponent(entityId, "Collidable")
                    local parentSize = collidable and collidable.radius or 20
                    local itemType = asteroid.asteroidType == "iron" and "iron" or "stone"
                    DestructionSystem.spawnItems(pos.x, pos.y, {
                        count = math.random(8, 15),
                        itemType = itemType,
                        distance = 0,
                        speed = {Constants.bit_spawn_speed_asteroid_min or 40, Constants.bit_spawn_speed_asteroid_max or 120}
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
            local lastDamager = ECS.getComponent(entityId, "LastDamager")

            -- Check if asteroid was destroyed by enemy (not player)
            local wasDestroyedByEnemy = false
            if asteroid and lastDamager then
                -- Check if the last damager was an AI-controlled entity (enemy)
                local damagerEntity = ECS.getComponent(lastDamager.pilotId, "AIController")
                if damagerEntity then
                    wasDestroyedByEnemy = true
                end
            end

            -- Wreckage shatters into bits
            if wreckage and pos then
                local collidable = ECS.getComponent(entityId, "Collidable")
                local parentSize = collidable and collidable.radius or 15
                DestructionSystem.spawnItems(pos.x, pos.y, {
                    count = math.random(5, 10),
                    itemType = "scrap",
                    distance = 50,
                    speed = {30, 80}
                })
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

return DestructionSystem