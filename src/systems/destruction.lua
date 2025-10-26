-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local WreckageSystem = require('src.systems.wreckage') -- Import WreckageSystem
local ItemDefs = require('src.items.item_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')
local SkillXP = require('src.systems.skill_xp')
local QuestUtils = require('src.quest_utils')
local DeathOverlay = require('src.ui.death_overlay')

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
                ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.8, 0.90)) -- Item drops: light mass, high damping
                ECS.addComponent(itemId, "Item", {id = type_, def = itemDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(quantity))
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
                -- Add polygon shape if supported by item (for precise highlights, but no Collidable)
                if itemDef.design and (itemDef.design.shape == "polygon" or itemDef.design.shape == "custom") then
                    local sz = (itemDef.design.size or 12)
                    -- Use a diamond/square polygon for universal fallback
                    local verts = {
                        {x = 0, y = -sz/2},
                        {x = sz/2, y = 0},
                        {x = 0, y = sz/2},
                        {x = -sz/2, y = 0}
                    }
                    ECS.addComponent(itemId, "PolygonShape", Components.PolygonShape(verts, 0))
                end
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
                ECS.addComponent(itemId, "Physics", Components.Physics(0.95, 0.8, 0.90)) -- Item drops: light mass, high damping
                ECS.addComponent(itemId, "Item", {id = type_, def = itemDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(1))
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemDef.design.color))
                -- Add polygon shape if supported by item (for precise highlights, but no Collidable)
                if itemDef.design and (itemDef.design.shape == "polygon" or itemDef.design.shape == "custom") then
                    local sz = (itemDef.design.size or 12)
                    -- Use a diamond/square polygon for universal fallback
                    local verts = {
                        {x = 0, y = -sz/2},
                        {x = sz/2, y = 0},
                        {x = 0, y = sz/2},
                        {x = -sz/2, y = 0}
                    }
                    ECS.addComponent(itemId, "PolygonShape", Components.PolygonShape(verts, 0))
                end
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
            
            -- Check if this is a projectile being destroyed
            local proj = ECS.getComponent(entityId, "Projectile")
            
            -- Check if this is the player's drone - if so, respawn instead of destroying
            local controlledBy = ECS.getComponent(entityId, "ControlledBy")
            if controlledBy and controlledBy.pilotId then
                local pilot = ECS.getComponent(controlledBy.pilotId, "Player")
                if pilot then
                    -- This is the player's drone - trigger death overlay UI, not instant respawn
                    DeathOverlay.show(
                        function() -- respawn callback
                            DestructionSystem.respawnPlayer(entityId, controlledBy.pilotId, true) -- 'true' = random spawn
                        end,
                        function() -- rage quit callback
                            love.event.quit('restart') -- Reload game, handled in main
                        end
                    )
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
                    
                    -- Determine item type and base count
                    local itemType = "stone"
                    local baseCount = math.random(8, 15)

                    if asteroid.asteroidType == "crystal" then
                        itemType = "crystal"
                        baseCount = math.random(3, 6)  -- Crystals are rarer, so fewer drop
                    elseif asteroid.asteroidType == "iron" then
                        itemType = "iron"
                        baseCount = math.random(6, 12)  -- Iron gives good yield
                    end

                    -- Crystal asteroids may also drop some stone fragments
                    if asteroid.asteroidType == "crystal" and math.random() < 0.3 then
                        DestructionSystem.spawnItems(pos.x + math.random(-10, 10), pos.y + math.random(-10, 10), {
                            {itemId = "stone", count = math.random(2, 4)}
                        })
                    end
                    
                    -- Size bonus: Larger asteroids give more resources
                    local sizeMultiplier = 1.0 + (parentSize / 100)  -- +1% per radius unit
                    baseCount = math.floor(baseCount * sizeMultiplier)
                    
                    -- Skill bonus: Higher mining skill increases yield
                    local playerEntities = ECS.getEntitiesWith({"Player", "Skills"})
                    if #playerEntities > 0 then
                        local skills = ECS.getComponent(playerEntities[1], "Skills")
                        if skills and skills.skills.mining then
                            local miningLevel = skills.skills.mining.level
                            local skillBonus = 1.0 + (miningLevel * 0.15)  -- +15% per level
                            baseCount = math.floor(baseCount * skillBonus)
                        end
                    end
                    
                    DestructionSystem.spawnItems(pos.x, pos.y, {
                        count = baseCount,
                        itemType = itemType,
                        distance = 0,
                        speed = {Constants.bit_spawn_speed_asteroid_min or 40, Constants.bit_spawn_speed_asteroid_max or 120}
                    })
                    
                    -- Mark asteroid for respawn in its cluster
                    local cluster = AsteroidClusters.getClusterForAsteroid(entityId)
                    if cluster then
                        AsteroidClusters.markForRespawn(entityId, cluster)
                    end
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
            local ai = ECS.getComponent(entityId, "AI")
            local wreckage = ECS.getComponent(entityId, "Wreckage")
            local lootDrop = ECS.getComponent(entityId, "LootDrop")
            local lastDamager = ECS.getComponent(entityId, "LastDamager")

            -- Check if asteroid was destroyed by enemy (not player)
            local wasDestroyedByEnemy = false
            if asteroid and lastDamager then
                -- Check if the last damager was an AI-controlled entity (enemy)
                local damagerEntity = ECS.getComponent(lastDamager.pilotId, "AI")
                if damagerEntity then
                    wasDestroyedByEnemy = true
                end
            end
            
            -- Check if enemy was destroyed by player
            local wasDestroyedByPlayer = false
            if ai and lastDamager then
                -- Check if the last damager was a player-controlled entity
                local damagerEntity = ECS.getComponent(lastDamager.pilotId, "Player")
                if damagerEntity then
                    wasDestroyedByPlayer = true
                end
            end

            -- Award mining XP if asteroid was destroyed by player
            if asteroid and not wasDestroyedByEnemy then
                local xpAmount = asteroid.xpReward
                SkillXP.awardXp("mining", xpAmount)
                
                -- Update quest progress for mining
                QuestUtils.updateMiningProgress()
            end
            
            -- Update combat quest progress if enemy was destroyed by player
            if ai and wasDestroyedByPlayer then
                QuestUtils.updateCombatProgress()
            end

            -- Spawn wreckage when ships are destroyed (AI-controlled or with Hull)
            if (ai or hull) and pos then
                local sourceShip = "unknown"

                -- Try to get ship type from wreckage component if it exists
                local existingWreckage = ECS.getComponent(entityId, "Wreckage")
                if existingWreckage and existingWreckage.sourceShip then
                    sourceShip = existingWreckage.sourceShip
                end

                -- Pass parent size (collision radius) so wreckage pieces scale visually
                local parentColl = ECS.getComponent(entityId, "Collidable")
                local parentSize = parentColl and parentColl.radius or 16
                WreckageSystem.spawnWreckage(pos.x, pos.y, sourceShip, parentSize)
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
function DestructionSystem.respawnPlayer(droneId, pilotId, randomLoc)
    -- If randomLoc: pick a random spawn point in world bounds
    local pos = ECS.getComponent(droneId, "Position")
    if pos then
        if randomLoc then
            local minX, maxX = -4000, 4000
            local minY, maxY = -3000, 3000
            pos.x = math.random(minX, maxX)
            pos.y = math.random(minY, maxY)
        else
            pos.x = 0
            pos.y = 0
        end
        pos.prevX = pos.x
        pos.prevY = pos.y
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
    end
    -- Restore shield to full if present
    local shield = ECS.getComponent(droneId, "Shield")
    if shield then
        shield.current = shield.max
        shield.lastDamageTime = 0  -- Reset shield regen timer
    end
end

return DestructionSystem