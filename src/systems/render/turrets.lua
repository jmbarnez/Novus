-- Render Turrets Module - Handles turret rendering

local ECS = require('src.ecs')
local Scaling = require('src.scaling')

-- Estimate an appropriate base radius for turret sizing from available components
local function estimateBaseRadius(entityId, polygonShape, renderable)
    if entityId then
        local collidable = ECS.getComponent(entityId, "Collidable")
        if collidable and collidable.radius then return collidable.radius end
    end
    if polygonShape and polygonShape.vertices then
        local r = 0
        for _, v in ipairs(polygonShape.vertices) do
            local d = math.sqrt((v.x or 0) * (v.x or 0) + (v.y or 0) * (v.y or 0))
            if d > r then r = d end
        end
        if r > 0 then return r end
    end
    if renderable and renderable.radius then return renderable.radius end
    return 12
end

-- Helper function to draw a turret on top of the drone
local function drawTurret(entityId, x, y, color, turretRotation, baseRadius)
    baseRadius = baseRadius or 12
    local config = ECS.getComponent(entityId, "TurretConfig") or {enabled = true, scale = 1.0, overhang = 4}
    if config.enabled == false then return nil, nil end
    local overhang = config.overhang or 4
    local scaleMult = config.scale or 1.0
    -- Scale barrel length and ensure a small overhang past the ship radius
    local barrelLength = math.max(10, math.floor(baseRadius * 0.9 * scaleMult) + overhang)
    local barrelHeight = math.max(4, math.floor(baseRadius * 0.2 * scaleMult))

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(turretRotation)
    love.graphics.rectangle("fill", 0, -barrelHeight/2, barrelLength, barrelHeight)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(math.max(1, math.floor(barrelHeight * 0.6)))
    love.graphics.rectangle("line", 0, -barrelHeight/2, barrelLength, barrelHeight)
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Place muzzle just beyond the hull edge
    local muzzleX = x + math.cos(turretRotation) * barrelLength
    local muzzleY = y + math.sin(turretRotation) * barrelLength
    return muzzleX, muzzleY
end

local RenderTurrets = {}
local DEBUG_TURRET_AIM = false

function RenderTurrets.drawPlayerTurret(entityId, position, polygonShape, renderable)
    local mouseScreenX, mouseScreenY = love.mouse.getPosition()
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    
    if cameraComp and cameraPos then
        -- Use helper to convert screen mouse coords to world coords (camera-aware)
        local mouseX, mouseY = Scaling.toWorld(mouseScreenX, mouseScreenY, cameraComp, cameraPos)
        -- atan2 handles full 360 degrees; use (dy, dx) order for proper angle calculation
        local aimAngle = math.atan2(mouseY - position.y, mouseX - position.x)
        local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
        local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
        local cos = math.cos(polygonShape.rotation)
        local sin = math.sin(polygonShape.rotation)
        local turretWorldX = position.x + (toffX * cos - toffY * sin)
        local turretWorldY = position.y + (toffX * sin + toffY * cos)
        local baseRadius = estimateBaseRadius(entityId, polygonShape, renderable)
        drawTurret(entityId, turretWorldX, turretWorldY, renderable.color, aimAngle, baseRadius)
        -- Debug drawing commented out - turret now works correctly in all 360 degrees
        -- if DEBUG_TURRET_AIM then
        --     -- Draw debug line from turret to mouse and print computed values
        --     love.graphics.push()
        --     love.graphics.setColor(1, 0, 0, 0.9)
        --     love.graphics.setLineWidth(2)
        --     love.graphics.line(turretWorldX, turretWorldY, mouseX, mouseY)
        --     love.graphics.setLineWidth(1)
        --     love.graphics.setColor(1, 1, 1, 1)
        --     local dx = mouseX - position.x
        --     local dy = mouseY - position.y
        --     local info = string.format("aim=%.3f\ndx=%.1f dy=%.1f", aimAngle or 0, dx or 0, dy or 0)
        --     love.graphics.print(info, turretWorldX + 8, turretWorldY - 16)
        --     love.graphics.pop()
        -- end
    else
        local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
        local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
        local cos = math.cos(polygonShape.rotation)
        local sin = math.sin(polygonShape.rotation)
        local turretWorldX = position.x + (toffX * cos - toffY * sin)
        local turretWorldY = position.y + (toffX * sin + toffY * cos)
    local baseRadius = estimateBaseRadius(entityId, polygonShape, renderable)
    drawTurret(entityId, turretWorldX, turretWorldY, renderable.color, polygonShape.rotation, baseRadius)
    end
end

function RenderTurrets.drawEnemyTurret(entityId, position, polygonShape, renderable)
    local enemyRotation = polygonShape.rotation or 0
    local turretAimAngle = enemyRotation
    local turretComp = ECS.getComponent(entityId, "Turret")
    if turretComp and turretComp.aimX and turretComp.aimY then
        -- Ensure (dy, dx) order for atan2
        turretAimAngle = math.atan2(turretComp.aimY - position.y, turretComp.aimX - position.x)
    end
    
    local toffX = polygonShape.turretOffsetX or polygonShape.cockpitOffsetX or 0
    local toffY = polygonShape.turretOffsetY or polygonShape.cockpitOffsetY or 0
    local cosE = math.cos(enemyRotation)
    local sinE = math.sin(enemyRotation)
    local turretWorldX = position.x + (toffX * cosE - toffY * sinE)
    local turretWorldY = position.y + (toffX * sinE + toffY * sinE)
    local baseRadius = estimateBaseRadius(entityId, polygonShape, renderable)
    drawTurret(entityId, turretWorldX, turretWorldY, renderable.color, turretAimAngle, baseRadius)
end

return RenderTurrets

