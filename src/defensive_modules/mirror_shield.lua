local ECS = require('src.ecs')
local Components = require('src.components')
local EntityHelpers = require('src.entity_helpers')
local Scaling = require('src.scaling')

local MirrorShield = {
    name = "mirror_shield",
    LIFETIME = 3.0,
    DISTANCE = 160, -- distance from ship center
    RADIUS = 36,
    ARC_ANGLE = math.pi * 0.6, -- 108 degrees arc
    ARC_SEGMENTS = 20 -- number of line segments for smooth arc
}

-- Helper: create mirror entity
local function createMirrorEntity(ownerId, x, y, dirX, dirY)
    local mirrorId = ECS.createEntity()
    ECS.addComponent(mirrorId, "Position", Components.Position(x, y))
    ECS.addComponent(mirrorId, "Velocity", Components.Velocity(0,0))
    ECS.addComponent(mirrorId, "Collidable", Components.Collidable(MirrorShield.RADIUS))
    
    -- Create arc visual effect - simple line segments
    local arcPoints = {}
    local startAngle = math.atan2(dirY, dirX) - MirrorShield.ARC_ANGLE / 2
    local angleStep = MirrorShield.ARC_ANGLE / MirrorShield.ARC_SEGMENTS
    
    for i = 0, MirrorShield.ARC_SEGMENTS do
        local angle = startAngle + i * angleStep
        local px = x + math.cos(angle) * MirrorShield.RADIUS
        local py = y + math.sin(angle) * MirrorShield.RADIUS
        arcPoints[#arcPoints + 1] = {x = px, y = py}
    end
    
    -- Use custom rendering component for arc
    ECS.addComponent(mirrorId, "Renderable", Components.Renderable("custom", nil, nil, nil, {0.9,0.9,0.6,0.8}))
    ECS.addComponent(mirrorId, "ArcShape", {points = arcPoints})
    
    -- Mark as ability for collision/laser reflection checks
    ECS.addComponent(mirrorId, "Ability", Components.Ability("mirror", ownerId, {x = dirX, y = dirY}))
    -- Use generic lifetime component so systems can manage expiration
    ECS.addComponent(mirrorId, "ProjectileLifetime", {age = 0, maxAge = MirrorShield.LIFETIME})
    -- Small polygon so linePolygonIntersect can hit it
    ECS.addComponent(mirrorId, "PolygonShape", Components.PolygonShape({{x=-MirrorShield.RADIUS,y=-MirrorShield.RADIUS},{x=MirrorShield.RADIUS,y=-MirrorShield.RADIUS},{x=MirrorShield.RADIUS,y=MirrorShield.RADIUS},{x=-MirrorShield.RADIUS,y=MirrorShield.RADIUS}}, 0))
    return mirrorId
end

function MirrorShield.equip(shipId)
    -- When equipped, just prepare the module - don't activate it yet
    -- The mirror shield will only activate when the player presses the hotbar key
end

function MirrorShield.unequip(shipId)
    -- Remove mirror entity if present
    if ECS.hasComponent(shipId, "ActiveMirror") then
        local m = ECS.getComponent(shipId, "ActiveMirror")
        if m and m.id and ECS.hasComponent(m.id, "Position") then
            ECS.destroyEntity(m.id)
        end
        ECS.removeComponent(shipId, "ActiveMirror")
    end
end

-- Toggle function for hotbar activation
function MirrorShield.activate(shipId)
    -- Toggle mirror shield on/off
    if ECS.hasComponent(shipId, "ActiveMirror") then
        -- Mirror is active, turn it off
        MirrorShield.unequip(shipId)
    else
        -- Mirror is not active, turn it on
        -- Get player position and cursor direction for initial activation
        local pilotId = EntityHelpers.getPlayerPilot()
        if not pilotId then return false end
        local input = ECS.getComponent(pilotId, "InputControlled")
        if not input or not input.targetEntity then return false end

        local ship = input.targetEntity
        local shipPos = ECS.getComponent(ship, "Position")
        if not shipPos then return false end

        -- Determine cursor world position (best effort)
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        local cameraComp = cameraEntities[1] and ECS.getComponent(cameraEntities[1], "Camera")
        local cameraPos = cameraEntities[1] and ECS.getComponent(cameraEntities[1], "Position")
        local mx, my = 0, 0
        if love and love.mouse and Scaling and cameraComp and cameraPos then
            mx, my = love.mouse.getPosition()
            mx, my = Scaling.toWorld(mx, my, cameraComp, cameraPos)
        else
            mx, my = shipPos.x + MirrorShield.DISTANCE, shipPos.y
        end

        local dx = mx - shipPos.x
        local dy = my - shipPos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local dirX, dirY = 1, 0
        if dist > 0 then dirX, dirY = dx / dist, dy / dist end

        local mxPos = shipPos.x + dirX * MirrorShield.DISTANCE
        local myPos = shipPos.y + dirY * MirrorShield.DISTANCE

        -- Create mirror entity and store reference on ship
        local mirrorId = createMirrorEntity(ship, mxPos, myPos, dirX, dirY)
        -- Store mirror reference on ship so we can remove on unequip
        ECS.addComponent(ship, "ActiveMirror", {id = mirrorId})
    end
    return true -- Indicate we handled the activation
end

return MirrorShield
