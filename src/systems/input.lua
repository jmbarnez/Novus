---@diagnostic disable: undefined-global
-- Input System - Handles player input
-- Translates keyboard and mouse input into entity actions

local ECS = require('src.ecs')
local Constants = require('src.constants')
local EntityHelpers = require('src.entity_helpers')
local TurretSystem = require('src.systems.turret')
local TurretRegistry = require('src.turret_registry')
local HotkeyConfig = require('src.hotkey_config')
local HUDHotbar = require('src.systems.hud.hotbar')

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

local function getControlledEntity()
    local controllers = ECS.getEntitiesWith({"InputControlled"})
    if #controllers == 0 then
        return nil
    end

    local controllerId = controllers[1]
    local inputComp = ECS.getComponent(controllerId, "InputControlled")
    if inputComp and inputComp.targetEntity then
        return inputComp.targetEntity
    end

    return controllerId
end

local function ensureTurretModuleRegistered(module, moduleName)
    if not module then
        return
    end
    local name = moduleName or module.name
    if not name then
        return
    end
    if not TurretRegistry.hasModule(name) then
        TurretRegistry.modules[name] = module
    end
end

local function tryActivateHotbarSlot(slotIndex)
    if not slotIndex then
        return false
    end

    local controlledEntity = getControlledEntity()
    if not controlledEntity then
        return false
    end

    local entries = HUDHotbar.getEntriesForDrone(controlledEntity)
    local entry = entries[slotIndex]
    if not entry or not entry.itemDef then
        return false
    end

    local module = entry.itemDef.module
    if not module and entry.sourceType == "turret" then
        local fallbackName = entry.itemId and entry.itemId:gsub("_turret$", "")
        if fallbackName then
            module = TurretRegistry.getModule(fallbackName)
        end
    end
    local handled = false

    if entry.sourceType == "turret" then
        local turret = ECS.getComponent(controlledEntity, "Turret")
        if turret then
            local moduleName = nil
            if module and module.name then
                moduleName = module.name
            else
                moduleName = entry.itemId and entry.itemId:gsub("_turret$", "")
            end

            ensureTurretModuleRegistered(module, moduleName)

            if moduleName then
                turret.moduleName = moduleName
                turret.lastFireTime = turret.lastFireTime or -999
                handled = true
            end
        end
    end

    if module then
        if module.activate then
            local result = module.activate(controlledEntity, entry.itemId)
            if result ~= false then
                handled = true
            end
        elseif module.use then
            module.use(controlledEntity, entry.itemId)
            handled = true
        elseif module.trigger then
            module.trigger(controlledEntity, entry.itemId)
            handled = true
        end
    end

    return handled
end

local function resolveHotbarSlotForKey(key)
    if not key or key == "" then
        return nil
    end
    if type(key) ~= "string" then
        return nil
    end
    local lowerKey = key:lower()
    for index, action in ipairs(HUDHotbar.actions or {}) do
        local binding = HotkeyConfig.getHotkey(action)
        if type(binding) == "string" and binding ~= "" and binding:lower() == lowerKey then
            return index
        end
    end
    return nil
end

local function mouseButtonToKey(button)
    if button == 1 then
        return "mouse1"
    elseif button == 2 then
        return "mouse2"
    elseif button == 3 then
        return "mouse3"
    end
    return nil
end

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

            -- Normalize diagonal movement so speed is consistent in all directions
            if thrust_x ~= 0 or thrust_y ~= 0 then
                local magnitude = math.sqrt(thrust_x * thrust_x + thrust_y * thrust_y)
                if magnitude > 0 then
                    -- Scale to maintain same thrust magnitude in all directions
                    thrust_x = thrust_x * thrustMagnitude / magnitude
                    thrust_y = thrust_y * thrustMagnitude / magnitude
                end
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

        local hotbarEntries = HUDHotbar.getEntriesForDrone(turretOwner)

        local function normalizeBinding(binding)
            if not binding or binding == "" then
                return nil
            end
            return binding:lower()
        end

        local function bindingHeld(bindingLower)
            if not bindingLower then
                return false
            end
            if bindingLower == "mouse1" then
                return love.mouse.isDown(1)
            elseif bindingLower == "mouse2" then
                return love.mouse.isDown(2)
            elseif bindingLower == "mouse3" then
                return love.mouse.isDown(3)
            else
                return love.keyboard.isDown(bindingLower)
            end
        end

        local function fireActive()
            local mouseX, mouseY = love.mouse.getPosition()

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

            TurretSystem.fireTurret(turretOwner, mouseX, mouseY, dt)

            local usesHeat = turretModule and turretModule.CONTINUOUS and turretModule.HEAT_RATE
            local canFire = true
            if usesHeat then
                if turret and turret.heat then
                    canFire = turret.heat.current < (turretModule.MAX_HEAT or 10)
                end
            end

            -- Check energy before calling applyBeam (energy already consumed by TurretSystem.fireTurret)
            -- Use hysteresis to avoid flicker: require larger buffer to start, smaller to continue; add short cooldown on depletion
            if canFire then
                local energyPerSecond = turretModule and turretModule.ENERGY_PER_SECOND
                local EnergySystem = require('src.systems.energy')
                if not energyPerSecond and EnergySystem and EnergySystem.CONSUMPTION then
                    energyPerSecond = EnergySystem.CONSUMPTION[turret.moduleName]
                end
                if energyPerSecond and dt and dt > 0 then
                    local energy = ECS.getComponent(turretOwner, "Energy")
                    local energyNeeded = energyPerSecond * dt
                    if energy then
                        -- Initialize a short cooldown timer on the turret component to prevent immediate restart flicker
                        if turret and turret.energyCooldownTimer == nil then
                            turret.energyCooldownTimer = 0
                        end
                        local now = love.timer.getTime()
                        if turret and now < (turret.energyCooldownTimer or 0) then
                            canFire = false
                        else
                            local isCurrentlyFiring = turret and turret.laserEntity ~= nil
                            if isCurrentlyFiring then
                                -- To continue firing, require a small reserve (min of energyNeeded and a small absolute value)
                                if energy.current < math.max(energyNeeded, 2.0) then
                                    canFire = false
                                    if turret then turret.energyCooldownTimer = now + 0.5 end
                                end
                            else
                                -- To start firing, require a larger buffer to avoid flicker as energy regenerates
                                if energy.current < energyNeeded * 3.0 then
                                    canFire = false
                                end
                            end
                        end
                    end
                end
            end

            if turretModule and turretModule.applyBeam and canFire then
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
                local turretComp = ECS.getComponent(turretOwner, "Turret")
                if turretComp and turretModule and turretModule.CONTINUOUS then
                    local heatRate = turretModule.HEAT_RATE or 1.0
                    turretComp.heat.current = math.min((turretComp.heat.current or 0) + heatRate * dt, turretModule.MAX_HEAT or 10)
                    if turretComp.heat.current >= (turretModule.MAX_HEAT or 10) then
                        turretComp.overheated = true
                    end
                end
                local laserEntityId = turretComp and turretComp.laserEntity
                if laserEntityId and laserEntityId > 0 then
                    local laserBeam = ECS.getComponent(laserEntityId, "LaserBeam")
                    if laserBeam then
                        laserBeam.start = {x = laserStartX, y = laserStartY}
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
                    end
                end
            end
        end

        local fired = false
        for slotIndex, action in ipairs(HUDHotbar.actions or {}) do
            local entry = hotbarEntries[slotIndex]
            if entry and entry.sourceType == "turret" then
                local slotModuleName
                if entry.itemDef and entry.itemDef.module and entry.itemDef.module.name then
                    slotModuleName = entry.itemDef.module.name
                else
                    slotModuleName = entry.itemId and entry.itemId:gsub("_turret$", "")
                end

                if slotModuleName == turret.moduleName then
                    local binding = HotkeyConfig.getHotkey(action)
                    local bindingLower = normalizeBinding(binding)
                    if bindingHeld(bindingLower) then
                        fireActive()
                        fired = true
                        break
                    end
                end
            end
        end

        if not fired then
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
    local slotIndex = resolveHotbarSlotForKey(key)
    if slotIndex then
        tryActivateHotbarSlot(slotIndex)
    end
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

    local mouseKey = mouseButtonToKey(button)
    if mouseKey then
        local slotIndex = resolveHotbarSlotForKey(mouseKey)
        if slotIndex then
            tryActivateHotbarSlot(slotIndex)
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
