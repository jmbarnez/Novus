---@diagnostic disable: undefined-global
-- Input System - Handles player input
-- Translates keyboard and mouse input into entity actions

local ECS = require('src.ecs')
local Constants = require('src.constants')
local EntityHelpers = require('src.entity_helpers')
local TurretSystem = require('src.systems.turret')
local TurretRegistry = require('src.turret_registry')
local HotkeyConfig = require('src.hotkey_config')

-- Lazy-load UISystem to avoid circular dependencies
local UISystem

local function getUISystem()
    if not UISystem then
        -- Get from Systems table to ensure same instance for input handling
        local Systems = require('src.systems')
        UISystem = Systems.UISystem
    end
    return UISystem
end

local InputSystem = {
    name = "InputSystem",
    priority = 1
}

function InputSystem.update(dt)
    -- Handle targeting progress
    local pilotId = EntityHelpers.getPlayerPilot()
    if pilotId then
        local controllers = {pilotId}
        for _, controllerId in ipairs(controllers) do
            local input = ECS.getComponent(controllerId, "InputControlled")
            if input and input.targetingTarget then
                -- Check if target still exists
                local targetPos = ECS.getComponent(input.targetingTarget, "Position")

                if targetPos then
                    -- Progress the lock-on regardless of mouse position
                    local currentTime = love.timer.getTime()
                    local elapsed = currentTime - input.targetingStartTime
                    input.targetingProgress = math.min(elapsed / 3.0, 1.0)  -- 3 second lock-on time

                    -- Complete targeting when progress reaches 1.0
                    if input.targetingProgress >= 1.0 then
                        input.targetedEnemy = input.targetingTarget
                        input.targetingTarget = nil
                        input.targetingProgress = 0
                        input.targetingStartTime = 0
                    end
                else
                    -- Target no longer exists, cancel targeting
                    input.targetingTarget = nil
                    input.targetingProgress = 0
                    input.targetingStartTime = 0
                end
            end
        end
    end

    -- Apply input from controller entities (pilots) to the controlled entity (drone)
    -- Uses THRUST (force-based) for realistic drone physics in space
    local ForceUtils = require('src.systems.force_utils')
    local allControllers = ECS.getEntitiesWith({"InputControlled"})
    for _, controllerId in ipairs(allControllers) do
        local input = ECS.getComponent(controllerId, "InputControlled")
        input = input or {speed = 300}
        local targetEntity = input and input.targetEntity or nil
        -- Prefer controlling the target entity if provided, otherwise control the controller itself
        local controlledEntity = targetEntity or controllerId
        
        -- Get force component (required for thrust-based control)
        local force = ECS.getComponent(controlledEntity, "Force")
        local physics = ECS.getComponent(controlledEntity, "Physics")
        
        if force and physics then
            -- Use thrustForce from Physics component if present, otherwise fall back to input.speed or default
            local thrustMagnitude = (physics.thrustForce) or (input and input.speed) or 300
            
            local thrust_x = 0
            local thrust_y = 0

            -- Use configurable movement keys
            local moveUp = HotkeyConfig.getHotkey("move_up")
            local moveDown = HotkeyConfig.getHotkey("move_down")
            local moveLeft = HotkeyConfig.getHotkey("move_left")
            local moveRight = HotkeyConfig.getHotkey("move_right")

            if love.keyboard.isDown(moveUp) then
                thrust_y = -thrustMagnitude
            end

            if love.keyboard.isDown(moveDown) then
                thrust_y = thrust_y + thrustMagnitude
            end

            if love.keyboard.isDown(moveLeft) then
                thrust_x = -thrustMagnitude
            end

            if love.keyboard.isDown(moveRight) then
                thrust_x = thrust_x + thrustMagnitude
            end

            -- Apply thrust force (accumulated with other forces this frame)
            ForceUtils.applyForce(controlledEntity, thrust_x, thrust_y)
        end
    end

    -- Handle weapon firing for entities with turrets
    -- If UI has captured mouse input, do not fire turrets
    local uiSys = getUISystem()
    if uiSys and uiSys.isMouseCaptured and uiSys.isMouseCaptured() then
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
                local turretModule = turret.moduleName and TurretRegistry.getModule(turret.moduleName) or nil
                if turretModule and turretModule.stopFiring then
                    turretModule.stopFiring(turret)
                elseif turret.laserEntity then
                    local laserBeam = ECS.getComponent(turret.laserEntity, "LaserBeam")
                    if laserBeam then
                        ECS.destroyEntity(turret.laserEntity)
                    end
                    turret.laserEntity = nil
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
        local turretModule = TurretRegistry.getModule(turret.moduleName)

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
            
            -- Apply beam effects every frame (damage, debris, beam positioning) and handle heat for laser turrets
            -- Only apply beam if turret heat hasn't reached MAX_HEAT (for laser turrets only)
            local usesHeat = turretModule and turretModule.CONTINUOUS and turretModule.HEAT_RATE
            local canFire = true
            if usesHeat then
                if turret and turret.heat then
                    canFire = turret.heat.current < (turretModule.MAX_HEAT or 10)
                end
            end
            
            if turretModule and turretModule.applyBeam and canFire then
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
                    turretComp.heat.current = math.min((turretComp.heat.current or 0) + heatRate * dt, turretModule.MAX_HEAT or 10)
                    if turretComp.heat.current >= (turretModule.MAX_HEAT or 10) then
                        turretComp.overheated = true
                    end
                end
                -- Also update the laser beam position on the entity
                local laserEntityId = turretComp and turretComp.laserEntity
                if laserEntityId and laserEntityId > 0 then
                    local laserBeam = ECS.getComponent(laserEntityId, "LaserBeam")
                    if laserBeam then
                        laserBeam.start = {x = laserStartX, y = laserStartY}
                        -- Use collision point if hit, otherwise use mouse position
                        if beamResult then
                            if beamResult.hit and beamResult.intersection then
                                laserBeam.endPos = {x = beamResult.intersection.x, y = beamResult.intersection.y}
                            elseif beamResult.endPos then
                                laserBeam.endPos = {x = beamResult.endPos.x, y = beamResult.endPos.y}
                            else
                                laserBeam.endPos = {x = mouseX, y = mouseY}
                            end
                        else
                            laserBeam.endPos = {x = mouseX, y = mouseY}
                        end
                        -- ...existing code...
                    end
                end
            end
        else
            -- Mouse released - destroy laser
            local turretModule = TurretRegistry.getModule(turret.moduleName)
            local turretComp = ECS.getComponent(turretOwner, "Turret")
            if turretComp then
                if turretModule and turretModule.stopFiring then
                    turretModule.stopFiring(turretComp)
                elseif turretComp.laserEntity then
                    local laserEntityId = turretComp.laserEntity
                    local laserBeam = ECS.getComponent(laserEntityId, "LaserBeam")
                    if laserBeam then
                        ECS.destroyEntity(laserEntityId)
                    end
                    turretComp.laserEntity = nil
                end
            end
            -- On release, start cooling down heat for continuous lasers
            if turretComp and turretComp.heat and turretComp.heat.current > 0 then
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
    -- Handle world tooltip button clicks first
    local WorldTooltips = require('src.systems.world_tooltips')
    if button == 1 and WorldTooltips and WorldTooltips.handleClick then
        if WorldTooltips.handleClick(x, y, button) then
            return
        end
    end

    -- Handle enemy targeting with configurable target key + Left Click
    local targetKey = HotkeyConfig.getHotkey("target_enemy")
    if button == 1 and love.keyboard.isDown(targetKey) then
        -- ...existing code...
        local mouseX, mouseY = x, y
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
            local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
            local Scaling = require('src.scaling')
            mouseX, mouseY = Scaling.toWorld(mouseX, mouseY, cameraComp, cameraPos)
        else
            local Scaling = require('src.scaling')
            mouseX, mouseY = Scaling.toUI(mouseX, mouseY)
        end
        local closestEnemy = nil
        local closestDist = math.huge
        local allAIEntities = ECS.getEntitiesWith({"AI", "Position", "Collidable"})
        local enemyEntities = {}
        for _, enemyId in ipairs(allAIEntities) do
            if not ECS.hasComponent(enemyId, "ControlledBy") then
                table.insert(enemyEntities, enemyId)
            end
        end
        for _, enemyId in ipairs(enemyEntities) do
            local enemyPos = ECS.getComponent(enemyId, "Position")
            local enemyColl = ECS.getComponent(enemyId, "Collidable")
            if enemyPos and enemyColl then
                local dx = mouseX - enemyPos.x
                local dy = mouseY - enemyPos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= (enemyColl.radius + 50) and dist < closestDist then
                    closestDist = dist
                    closestEnemy = enemyId
                end
            end
        end
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers > 0 then
            local inputComp = ECS.getComponent(controllers[1], "InputControlled")
            if inputComp then
                inputComp.targetedEnemy = nil
                inputComp.targetingTarget = closestEnemy
                inputComp.targetingProgress = 0
                inputComp.targetingStartTime = love.timer.getTime()
            end
        end
        return
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

        if camera then
            local current = camera.targetZoom or camera.zoom or 1
            local zoomSpeed = 0.05 -- Speed of zoom adjustment per scroll tick
            local minZoom = 1.0  -- Zoom out limit (1.0 = normal view)
            local maxZoom = 2.0  -- Zoom in limit (2.0 = 2x magnification)
            
            if y > 0 then -- Mouse wheel up (zoom in)
                camera.targetZoom = math.min(current + zoomSpeed, maxZoom)
            elseif y < 0 then -- Mouse wheel down (zoom out)
                camera.targetZoom = math.max(current - zoomSpeed, minZoom)
            end
        end
    end
end

return InputSystem
