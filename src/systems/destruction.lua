---@diagnostic disable: undefined-global
-- Destruction System - Handles entity destruction and death effects

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local DebrisSystem = require('src.systems.debris') -- Import DebrisSystem
local WreckageSystem = require('src.systems.wreckage') -- Import WreckageSystem
local ItemDefs = require('src.items.item_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')
local SkillXP = require('src.systems.skill_xp')
local TurretModuleLoader = require('src.turret_module_loader')
local EventSystem = require('src.systems.event_system')
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
                -- If this item is a turret module, create an instance copy so we can attach per-item modifiers/level
                local finalDef = itemDef
                if itemDef.module then
                    -- Allow caller to request a module instance with a specific level for loot
                    local moduleOpts = {loot = true}
                    if params.moduleLevel then moduleOpts.level = params.moduleLevel end
                    local instanceModule = TurretModuleLoader.createInstance(itemDef.module, moduleOpts)
                    if instanceModule then
                        -- shallow copy itemDef to avoid mutating global defs
                        finalDef = {}
                        for k, v in pairs(itemDef) do finalDef[k] = v end
                        finalDef.module = instanceModule
                    end
                end
                ECS.addComponent(itemId, "Item", {id = type_, def = finalDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(quantity))
                -- Safely get item color, fallback to default gray if no design
                local itemColor = (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemColor))
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
                -- If this item is a turret module, attach an instance with randomized modifiers for looted modules
                local finalDef = itemDef
                if itemDef.module then
                    local instanceModule = TurretModuleLoader.createInstance(itemDef.module, {loot = true})
                    if instanceModule then
                        finalDef = {}
                        for k, v in pairs(itemDef) do finalDef[k] = v end
                        finalDef.module = instanceModule
                    end
                end
                ECS.addComponent(itemId, "Item", {id = type_, def = finalDef})
                ECS.addComponent(itemId, "Stack", Components.Stack(1))
                -- Safely get item color, fallback to default gray if no design
                local itemColor = (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                ECS.addComponent(itemId, "Renderable", Components.Renderable("item", nil, nil, nil, itemColor))
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
                     -- This is the player's drone. Capture the ship design for respawn and
                     -- show the death overlay. Do NOT skip destruction here so the ship
                     -- entity is actually removed and the player cannot keep flying.
                     local shipDesignId = "starter_drone"
                     local wreckComp = ECS.getComponent(entityId, "Wreckage")
                     if wreckComp and wreckComp.sourceShip then
                         shipDesignId = wreckComp.sourceShip
                     end

                    DeathOverlay.show(
                          function() -- respawn callback: create a new ship for the player
                             DestructionSystem.respawnPlayer(controlledBy.pilotId, shipDesignId, true) -- 'true' = random spawn
                        end,
                        function() -- rage quit callback
                            love.event.quit('restart') -- Reload game, handled in main
                        end
                    )
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
                    -- Only award/spawn loot if the last damager exists, is recent, and is a player
                    local lastDamager = ECS.getComponent(entityId, "LastDamager")
                    local shouldDrop = false
                    if lastDamager and lastDamager.pilotId and lastDamager.timestamp then
                        local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.time()
                        local age = now - lastDamager.timestamp
                        if age <= 2 then -- only attribute to recent damagers (2s)
                            if ECS.hasComponent(lastDamager.pilotId, "Player") then
                                shouldDrop = true
                            end
                        end
                    end

                    if shouldDrop then
                        -- Determine item type based on asteroid type
                        local itemType = "stone"
                        if asteroid.asteroidType == "crystal" then
                            itemType = "crystal"
                        elseif asteroid.asteroidType == "iron" then
                            itemType = "iron"
                        end

                        -- Drop 2-4 of the asteroid's resource type
                        local count = math.random(2, 4)

                        -- Spawn items
                        DestructionSystem.spawnItems(pos.x, pos.y, {
                            count = count,
                            itemType = itemType,
                            distance = 0,
                            speed = {Constants.bit_spawn_speed_asteroid_min or 40, Constants.bit_spawn_speed_asteroid_max or 120}
                        })

                        -- TODO: Tag spawned items with an "ownerPilotId" or similar so only the lastDamager can pick them up.

                        -- Mark asteroid for respawn in its cluster
                        local cluster = AsteroidClusters.getClusterForAsteroid(entityId)
                        if cluster then
                            AsteroidClusters.markForRespawn(entityId, cluster)
                        end
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
            if asteroid and lastDamager and lastDamager.pilotId then
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

            -- Award mining XP ONLY if asteroid was destroyed by player (has LastDamager and not enemy AI)
            if asteroid and lastDamager and not wasDestroyedByEnemy then
                local xpAmount = asteroid.xpReward or SkillXP.getXpGain("mining")
                -- Deliver XP to the player who last damaged this asteroid
                if lastDamager and lastDamager.pilotId then
                    EventSystem.emitTo("SkillGain", lastDamager.pilotId, { skill = "mining", xp = xpAmount }, lastDamager.pilotId)
                else
                    EventSystem.emitGlobal("SkillGain", { skill = "mining", xp = xpAmount }, nil)
                end

                -- Update quest progress for mining
                QuestUtils.updateMiningProgress()
            end
            
            -- Update combat quest progress if enemy was destroyed by player
            if ai and wasDestroyedByPlayer then
                -- Determine skill to award based on weapon type recorded on LastDamager
                local skillName = nil
                local weaponType = lastDamager and lastDamager.weaponType or nil
                if weaponType then
                    -- Try to map weapon type/module name to a turret module definition
                    local turretModule = TurretModuleLoader.getTurretModuleByName(weaponType)
                    if turretModule and turretModule.skill then
                        skillName = turretModule.skill
                    end
                end
                if skillName then
                    local xpAmount = SkillXP.getXpGain(skillName)
                if lastDamager and lastDamager.pilotId then
                    local skillGainData = { skill = skillName, xp = xpAmount }
                        if weaponType then
                            skillGainData.weaponType = weaponType
                    end
                    EventSystem.emitTo("SkillGain", lastDamager.pilotId, skillGainData, lastDamager.pilotId)
                else
                    EventSystem.emitGlobal("SkillGain", { skill = skillName, xp = xpAmount }, nil)
                    end
                end
                if not skillName then
                    -- Debug: log unresolved weapon->skill mapping to help diagnose missing XP
                    local info = "[Destruction] No skill resolved for weaponType=" .. tostring(lastDamager and lastDamager.weaponType) .. " pilot=" .. tostring(lastDamager and lastDamager.pilotId)
                    print(info)
                end

                -- Get the enemy type from the Wreckage component (which stores the ship design ID)
                local wreckage = ECS.getComponent(entityId, "Wreckage")
                local enemyType = wreckage and wreckage.sourceShip or nil
                QuestUtils.updateCombatProgress(enemyType)
                
                -- (Turret drop handled separately for all destroyed ships)
            end

            -- Spawn wreckage when ships are destroyed (any ship with Hull component)
            -- But NOT when wreckage pieces are destroyed - wreckage only spawns scrap
            -- Ships have both Hull and Wreckage components (Wreckage stores sourceShip)
            -- Actual wreckage pieces have Wreckage but NO Hull component
            -- So: spawn wreckage if has Hull (includes both AI and player ships)
            if hull and pos then
                local sourceShip = "unknown"

                -- Try to get ship type from wreckage component if it exists
                local existingWreckage = ECS.getComponent(entityId, "Wreckage")
                if existingWreckage and existingWreckage.sourceShip then
                    sourceShip = existingWreckage.sourceShip
                end

                -- Calculate ship's total surface area from polygon shape
                local totalSurfaceArea = 0
                local polygonShape = ECS.getComponent(entityId, "PolygonShape")
                if polygonShape and polygonShape.vertices then
                    totalSurfaceArea = Components.calculatePolygonArea(polygonShape.vertices)
                end
                
                -- Fallback: estimate area from collision radius if no polygon
                if totalSurfaceArea == 0 then
                local parentColl = ECS.getComponent(entityId, "Collidable")
                    local parentRadius = parentColl and parentColl.radius or 16
                    -- Estimate area as circle: π * r^2
                    totalSurfaceArea = math.pi * parentRadius * parentRadius
                end

                WreckageSystem.spawnWreckage(pos.x, pos.y, sourceShip, totalSurfaceArea)

                -- Ship loot: 50% chance to drop turret module (if this entity had one)
                do
                    local turret = ECS.getComponent(entityId, "Turret")
                    if turret and turret.moduleName and pos and math.random() < 0.5 then
                        local TurretRegistry = require('src.turret_registry')
                        local module = TurretRegistry.getModule(turret.moduleName)
                        if module then
                            local itemId = module.id or module.itemId
                            if itemId and ItemDefs[itemId] then
                                local enemyLevel = ECS.getComponent(entityId, "Level")
                                local enemyLevelValue = enemyLevel and enemyLevel.level or 1
                                DestructionSystem.spawnItems(pos.x, pos.y, {
                                    count = 1,
                                    itemType = itemId,
                                    distance = 60,
                                    speed = {40, 100},
                                    stackItems = false,
                                    moduleLevel = enemyLevelValue
                                })
                            end
                        end
                    end
                end
            end

            -- Wreckage shatters into scrap pieces (only when an actual wreckage piece is destroyed)
            -- Skip spawning scrap for ship entities (ships spawn wreckage pieces instead)
            if wreckage and not ai and not hull and pos then
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

-- Respawn the player's drone by creating a new ship entity
-- @param pilotId number: The player pilot entity ID
-- @param shipDesignId string: The ship design to respawn with
-- @param randomLoc boolean: If true, spawn at random location; if false, spawn at (0, 0)
function DestructionSystem.respawnPlayer(pilotId, shipDesignId, randomLoc)
    if not pilotId then return end
    
    local ShipLoader = require('src.ship_loader')
    
    -- Calculate spawn position
    local spawnX, spawnY = 0, 0
        if randomLoc then
            local minX, maxX = -4000, 4000
            local minY, maxY = -3000, 3000
        spawnX = math.random(minX, maxX)
        spawnY = math.random(minY, maxY)
    end
    
    -- Create new ship entity
    local newShipId = ShipLoader.createShip(shipDesignId or "starter_drone", spawnX, spawnY, "player", pilotId)
    
    if not newShipId then
        -- Fallback: try to create starter drone if design not found
        newShipId = ShipLoader.createShip("starter_drone", spawnX, spawnY, "player", pilotId)
    end
    
    -- Link the pilot's InputControlled to the new ship (ShipLoader should do this, but ensure it)
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    if inputComp and newShipId then
        inputComp.targetEntity = newShipId
    end
end

return DestructionSystem