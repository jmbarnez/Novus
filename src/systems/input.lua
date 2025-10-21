---@diagnostic disable: undefined-global
-- Input System - Handles player input
-- Translates keyboard and mouse input into entity actions

local ECS = require('src.ecs')
local Constants = require('src.constants')
local TurretSystem = require('src.systems.turret')

local InputSystem = {
    name = "InputSystem",
    priority = 1
}

function InputSystem.update(dt)
    -- Apply input from controller entities (pilots) to the controlled entity (drone)
    local controllers = ECS.getEntitiesWith({"InputControlled"})
    for _, controllerId in ipairs(controllers) do
    local input = ECS.getComponent(controllerId, "InputControlled")
    input = input or {speed = 300}
        local targetEntity = input and input.targetEntity or nil
        -- Prefer controlling the target entity if provided, otherwise control the controller itself
        local accelEntity = targetEntity or controllerId
        local acceleration = ECS.getComponent(accelEntity, "Acceleration")
        if not acceleration then
            -- If no Acceleration on target, skip
        else
            local new_ax = 0
            local new_ay = 0

            if love.keyboard.isDown("w") then
                new_ay = -input.speed
            end

            if love.keyboard.isDown("s") then
                new_ay = input.speed
            end

            if love.keyboard.isDown("a") then
                new_ax = -input.speed
            end

            if love.keyboard.isDown("d") then
                new_ax = input.speed
            end

            acceleration.ax = new_ax
            acceleration.ay = new_ay
        end
    end

    -- Handle weapon firing for entities with turrets
    -- If UI has captured mouse input, do not fire turrets
    local UIS = ECS.getSystem("UISystem")
    if UIS and UIS.isMouseCaptured and UIS.isMouseCaptured() then
        -- If turret beams exist, clean them up (as a safety) for the player's controlled drone
        local controllersList = ECS.getEntitiesWith({"InputControlled"})
        local controllerId = controllersList[1]
        local turretOwner = nil
        if controllerId then
            local input = ECS.getComponent(controllerId, "InputControlled")
            if input and input.targetEntity then
                turretOwner = input.targetEntity
            end
        end
        if not turretOwner then
            local turretEntities = ECS.getEntitiesWith({"Turret", "Position"})
            if #turretEntities > 0 then
                turretOwner = turretEntities[1]
            end
        end
        if turretOwner then
            local turret = ECS.getComponent(turretOwner, "Turret")
            if turret then
                local turretModule = TurretSystem.turretModules[turret.moduleName]
                if turretModule and turretModule.laserEntity then
                    local laserBeam = ECS.getComponent(turretModule.laserEntity, "LaserBeam")
                    if laserBeam then
                        ECS.destroyEntity(turretModule.laserEntity)
                        turretModule.laserEntity = nil
                    end
                end
            end
        end
        return
    end
    -- Find the pilot/controller entity to determine which turret to fire
    local controllersList = ECS.getEntitiesWith({"InputControlled"})
    local controllerId = controllersList[1]
    local turretOwner = nil
    if controllerId then
        local input = ECS.getComponent(controllerId, "InputControlled")
        if input and input.targetEntity then
            turretOwner = input.targetEntity
        end
    end
    -- Fallback: find any entity with a turret
    if not turretOwner then
        local turretEntities = ECS.getEntitiesWith({"Turret", "Position"})
        if #turretEntities > 0 then
            turretOwner = turretEntities[1]
        end
    end
    if turretOwner then
        local playerPos = ECS.getComponent(turretOwner, "Position")
        local turret = ECS.getComponent(turretOwner, "Turret")
        
        -- Get the module for this turret
        local turretModule = TurretSystem.turretModules[turret.moduleName]

        -- Check if turret has a valid module installed (moduleName is not nil)
        if not turret or not turret.moduleName or not turretModule then
            -- No module installed or module not found, don't fire
            return
        end
        
        if not playerPos then return end
        
        if love.mouse.isDown(1) then -- Left mouse button held
            local mouseX, mouseY = love.mouse.getPosition()
            
            -- Convert screen coordinates to world coordinates using Scaling helper
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            if #cameraEntities > 0 then
                local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
                local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
                local Scaling = require('src.scaling')
                mouseX, mouseY = Scaling.toWorld(mouseX, mouseY, cameraComp, cameraPos)
            else
                -- Fallback: convert using global canvas transform if present
                local Scaling = require('src.scaling')
                mouseX, mouseY = Scaling.toUI(mouseX, mouseY)
            end
            
            -- Fire the turret (creates/updates laser beam on cooldown); pass dt for heat accumulation
            TurretSystem.fireTurret(turretOwner, mouseX, mouseY, dt)
            
            -- Apply beam effects every frame (damage, debris, beam positioning) and handle heat for continuous lasers
            -- Projectiles apply damage in the CollisionSystem/ProjectileSystem,
            -- Lasers apply damage in their applyBeam functions (handled in module).
            -- Only apply beam if turret is not overheated
            if turretModule and turretModule.applyBeam and not turret.overheated then
                -- Offset laser start position away from ship to avoid self-collision
                local laserStartX = playerPos.x
                local laserStartY = playerPos.y
                local collider = ECS.getComponent(turretOwner, "Collidable")
                if collider then
                    local dx = mouseX - playerPos.x
                    local dy = mouseY - playerPos.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 0 then
                        laserStartX = playerPos.x + (dx / dist) * (collider.radius + 5)
                        laserStartY = playerPos.y + (dy / dist) * (collider.radius + 5)
                    end
                end

                local beamResult = turretModule.applyBeam(turretOwner, laserStartX, laserStartY, mouseX, mouseY, dt, turret)
                -- Handle heat accumulation for continuous weapons
                local turretComp = ECS.getComponent(turretOwner, "Turret")
                if turretComp and turretModule and turretModule.CONTINUOUS then
                    -- Grow heat, and trigger overheat if exceeding MAX_HEAT
                    local heatRate = turretModule.HEAT_RATE or 1.0
                    turretComp.heat = math.min((turretComp.heat or 0) + heatRate * dt, turretModule.MAX_HEAT or 10)
                    if turretComp.heat >= (turretModule.MAX_HEAT or 10) then
                        turretComp.overheated = true
                    end
                end
                -- Also update the laser beam position on the entity
                if turretModule.laserEntity and turretModule.laserEntity > 0 then
                    local laserBeam = ECS.getComponent(turretModule.laserEntity, "LaserBeam")
                    if laserBeam then
                        laserBeam.start = {x = laserStartX, y = laserStartY}
                        -- Use collision point if hit, otherwise use mouse position
                        if beamResult and beamResult.hit and beamResult.intersection then
                            laserBeam.endPos = {x = beamResult.intersection.x, y = beamResult.intersection.y}
                        else
                            laserBeam.endPos = {x = mouseX, y = mouseY}
                        end
                        -- ...existing code...
                    end
                end
            end
        else
            -- Mouse released - destroy laser
            local turretModule = TurretSystem.turretModules[turret.moduleName]
            if turretModule and turretModule.laserEntity then
                local laserBeam = ECS.getComponent(turretModule.laserEntity, "LaserBeam")
                if laserBeam then
                    ECS.destroyEntity(turretModule.laserEntity)
                    turretModule.laserEntity = nil
                end
            end
                    -- On release, start cooling down heat for continuous lasers
                    local turretComp = ECS.getComponent(turretOwner, "Turret")
                    if turretComp and turretComp.heat and turretComp.heat > 0 then
                        -- We'll rely on TurretSystem.update to cool down over time
                    end
        end
    end
end

function InputSystem.keypressed(key)
    -- Tab key handling will be done in core.lua to avoid circular dependency
end

function InputSystem.keyreleased(key)
    -- Placeholder for key released input handling
end

function InputSystem.mousemoved(x, y, dx, dy, isTouch)
    -- This function can be used for other mouse movement related logic if needed.
end

function InputSystem.mousepressed(x, y, button, istouch, presses)
    -- Handle enemy targeting with Ctrl + Left Click
    if button == 1 and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Get mouse position in world coordinates
        local mouseX, mouseY = x, y

        -- Convert screen coordinates to world coordinates using Scaling helper
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
            local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
            local Scaling = require('src.scaling')
            mouseX, mouseY = Scaling.toWorld(mouseX, mouseY, cameraComp, cameraPos)
        else
            -- Fallback: convert using global canvas transform if present
            local Scaling = require('src.scaling')
            mouseX, mouseY = Scaling.toUI(mouseX, mouseY)
        end

        -- Find closest enemy ship
        local closestEnemy = nil
        local closestDist = math.huge

        -- Get all enemy ships (entities with CombatAI or MiningAI but not controlled by player)
        local enemyEntities = {}
        local combatEnemies = ECS.getEntitiesWith({"CombatAI", "Position", "Collidable"})
        local miningEnemies = ECS.getEntitiesWith({"MiningAI", "Position", "Collidable"})

        for _, enemyId in ipairs(combatEnemies) do
            if not ECS.hasComponent(enemyId, "ControlledBy") then
                table.insert(enemyEntities, enemyId)
            end
        end

        for _, enemyId in ipairs(miningEnemies) do
            if not ECS.hasComponent(enemyId, "ControlledBy") then
                table.insert(enemyEntities, enemyId)
            end
        end

        -- Find closest enemy to mouse position
        for _, enemyId in ipairs(enemyEntities) do
            local enemyPos = ECS.getComponent(enemyId, "Position")
            local enemyColl = ECS.getComponent(enemyId, "Collidable")

            if enemyPos and enemyColl then
                local dx = mouseX - enemyPos.x
                local dy = mouseY - enemyPos.y
                local dist = math.sqrt(dx * dx + dy * dy)

                -- Check if mouse is within reasonable targeting range (enemy radius + some tolerance)
                if dist <= (enemyColl.radius + 50) and dist < closestDist then
                    closestDist = dist
                    closestEnemy = enemyId
                end
            end
        end

        -- Set the targeted enemy on the player controller
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers > 0 then
            local inputComp = ECS.getComponent(controllers[1], "InputControlled")
            if inputComp then
                inputComp.targetedEnemy = closestEnemy
            end
        end

        return -- Don't process as regular left click
    end
end

function InputSystem.wheelmoved(x, y)
    -- Forward wheel events to MapWindow for zoom control if open
    local MapWindow = require('src.ui.map_window')
    if MapWindow and MapWindow.getOpen and MapWindow:getOpen() then
        MapWindow:wheelmoved(x, y)
        return
    end

    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local camera = ECS.getComponent(cameraId, "Camera")

        local zoomStep = 0.1 -- How much zoom changes per wheel tick

        if camera then
            if y > 0 then -- Mouse wheel up (zoom in)
                camera.targetZoom = math.min((camera.targetZoom or camera.zoom or 1) + zoomStep, 2.0)
            elseif y < 0 then -- Mouse wheel down (zoom out)
                camera.targetZoom = math.max((camera.targetZoom or camera.zoom or 1) - zoomStep, 0.5)
            end
        end
    end
end

return InputSystem
