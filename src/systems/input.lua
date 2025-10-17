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
    local entities = ECS.getEntitiesWith({"InputControlled", "Acceleration"})

    for _, entityId in ipairs(entities) do
        local acceleration = ECS.getComponent(entityId, "Acceleration")
        local input = ECS.getComponent(entityId, "InputControlled")

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

    -- Handle weapon firing for entities with turrets
    local turretEntities = ECS.getEntitiesWith({"Turret", "Position"})
    if #turretEntities > 0 then
        local playerEntity = turretEntities[1] -- Typically the player
        local playerPos = ECS.getComponent(playerEntity, "Position")
        local turret = ECS.getComponent(playerEntity, "Turret")
        
        if love.mouse.isDown(1) then -- Left mouse button held
            local mouseX, mouseY = love.mouse.getPosition()
            
            -- Convert screen coordinates to world coordinates
            local canvasEntities = ECS.getEntitiesWith({"Canvas"})
            local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
            if #canvasEntities > 0 and #cameraEntities > 0 then
                local canvasComp = ECS.getComponent(canvasEntities[1], "Canvas")
                local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
                local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
                
                -- Convert screen to world coordinates
                mouseX = (mouseX / cameraComp.zoom - canvasComp.offsetX) / canvasComp.scale + cameraPos.x
                mouseY = (mouseY / cameraComp.zoom - canvasComp.offsetY) / canvasComp.scale + cameraPos.y
            end
            
            -- Fire the turret (creates/updates laser beam on cooldown)
            TurretSystem.fireTurret(playerEntity, mouseX, mouseY)
            
            -- Apply beam effects every frame (damage, debris, beam positioning)
            local turretModule = TurretSystem.turretModules[turret.moduleName]
            if turretModule and turretModule.applyBeam then
                local beamResult = turretModule.applyBeam(playerEntity, playerPos.x, playerPos.y, mouseX, mouseY, dt)
                -- Also update the laser beam position on the entity
                if turretModule.laserEntity and turretModule.laserEntity > 0 then
                    local laserBeam = ECS.getComponent(turretModule.laserEntity, "LaserBeam")
                    if laserBeam then
                        laserBeam.start = {x = playerPos.x, y = playerPos.y}
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
        end
    end
end

function InputSystem.keypressed(key)
    -- Tab key handling will be done in core.lua to avoid circular dependency
    -- Placeholder for key pressed input handling
end

function InputSystem.keyreleased(key)
    -- Placeholder for key released input handling
end

function InputSystem.mousemoved(x, y, dx, dy, isTouch)
    -- This function can be used for other mouse movement related logic if needed.
end

function InputSystem.wheelmoved(x, y)
    local cameraEntities = ECS.getEntitiesWith({"Camera"})
    if #cameraEntities > 0 then
        local cameraId = cameraEntities[1]
        local camera = ECS.getComponent(cameraId, "Camera")
        
        local zoomStep = 0.1 -- How much zoom changes per wheel tick
        
        if y > 0 then -- Mouse wheel up (zoom in)
            camera.targetZoom = math.min(camera.targetZoom + zoomStep, 2.0)
        elseif y < 0 then -- Mouse wheel down (zoom out)
            camera.targetZoom = math.max(camera.targetZoom - zoomStep, 0.5)
        end
    end
end

return InputSystem
