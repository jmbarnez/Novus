-- Render Effects Module - Handles visual effects (lasers, debris, hotspots, etc.)

local ECS = require('src.ecs')

local RenderEffects = {}

local unpack = table.unpack or unpack

local function drawBeamPath(points, color)
    if not points or #points < 2 then
        return
    end
    local coords = {}
    for _, pt in ipairs(points) do
        coords[#coords + 1] = pt.x
        coords[#coords + 1] = pt.y
    end

    love.graphics.setColor(color[1], color[2], color[3], 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.line(unpack(coords))

    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.line(unpack(coords))
end

function RenderEffects.drawLasers()
    local laserEntities = ECS.getEntitiesWith({"LaserBeam"})
    for _, entityId in ipairs(laserEntities) do
        local laser = ECS.getComponent(entityId, "LaserBeam")
        if laser then
            local color = laser.color or {1, 1, 0, 1}
            if laser.segments and #laser.segments >= 2 then
                drawBeamPath(laser.segments, color)
            else
                drawBeamPath({laser.start, laser.endPos}, color)
            end

            if laser.chainSegments and #laser.chainSegments >= 2 then
                local chainColor = laser.chainColor or color
                drawBeamPath(laser.chainSegments, chainColor)
            end

            -- Reset line width for other renderers
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function RenderEffects.drawDebris()
    local debrisEntities = ECS.getEntitiesWith({"DebrisParticle"})
    for _, entityId in ipairs(debrisEntities) do
        local particle = ECS.getComponent(entityId, "DebrisParticle")
        if particle then
            local alpha = particle.life / particle.maxLife
            if particle.color and particle.color[1] and particle.color[2] and particle.color[3] and particle.color[4] then
                love.graphics.setColor(
                    particle.color[1],
                    particle.color[2],
                    particle.color[3],
                    particle.color[4] * alpha
                )
                love.graphics.circle("fill", particle.x, particle.y, particle.size)
            end
        end
    end
end

function RenderEffects.drawTrails()
    local trailEntities = ECS.getEntitiesWith({"TrailParticle"})
    for _, entityId in ipairs(trailEntities) do
        local particle = ECS.getComponent(entityId, "TrailParticle")
        if particle and particle.life and particle.maxLife and particle.color and particle.x and particle.y and particle.size then
            local alpha = particle.life / particle.maxLife
            love.graphics.setColor(
                particle.color[1] or 1,
                particle.color[2] or 1,
                particle.color[3] or 1,
                (particle.color[4] or 1) * alpha
            )
            love.graphics.circle("fill", particle.x, particle.y, particle.size)
        end
    end
end

function RenderEffects.drawMagneticField()
    local ships = ECS.getEntitiesWith({"MagneticField", "Position", "ControlledBy"})
    for _, shipId in ipairs(ships) do
        local magField = ECS.getComponent(shipId, "MagneticField")
        local position = ECS.getComponent(shipId, "Position")
        if magField and magField.active and position then
            local radius = magField.range
            local time = love.timer.getTime()
            local pulse = 0.3 + 0.2 * math.sin(time * 4)
            love.graphics.setColor(0.4, 0.8, 1, pulse * 0.3)
            love.graphics.circle("line", position.x, position.y, radius)
            love.graphics.setColor(0.6, 0.9, 1, pulse * 0.2)
            love.graphics.circle("line", position.x, position.y, radius * 0.7)
        end
    end
end

function RenderEffects.drawTargetingIndicator()
    local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
    if #controllers > 0 then
        local inputComp = ECS.getComponent(controllers[1], "InputControlled")
        local targetId = inputComp and (inputComp.targetedEnemy or inputComp.targetingTarget)

        if inputComp and targetId then
            local targetPos = ECS.getComponent(targetId, "Position")
            local targetColl = ECS.getComponent(targetId, "Collidable")

            if targetPos and targetColl then
                local time = love.timer.getTime()
                local radius = targetColl.radius + 15

                if inputComp.targetedEnemy and inputComp.targetedEnemy == targetId then
                    local pulse = 0.5 + 0.3 * math.sin(time * 4)

                    love.graphics.setColor(1, 0.2, 0.2, pulse)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                    love.graphics.setColor(1, 0.5, 0.5, pulse * 0.7)
                    love.graphics.setLineWidth(1)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                elseif inputComp.targetingTarget and inputComp.targetingTarget == targetId then
                    local pulse = 0.4 + 0.4 * math.sin(time * 8)

                    love.graphics.setColor(1, 0.8, 0.2, pulse)
                    love.graphics.setLineWidth(3)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius)

                    love.graphics.setColor(1, 0.9, 0.5, pulse * 0.7)
                    love.graphics.setLineWidth(1)
                    love.graphics.circle("line", targetPos.x, targetPos.y, radius - 5)
                end
            end
        end
    end
end

-- Warp gate canvas cache to avoid redrawing static geometry every frame
local warpGateCache = {
    active = nil,    -- Canvas for active gate
    inactive = nil,  -- Canvas for inactive gate
    radius = 80,     -- Default radius used for cache
    lastUpdate = 0   -- Last time cache was updated
}

-- Generate warp gate canvas (static parts only)
local function generateWarpGateCanvas(active, radius)
    local size = (radius + 60) * 2
    local canvas = love.graphics.newCanvas(size, size)
    local cx, cy = size / 2, size / 2
    
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    
    if active then
        -- Metallic structure (static)
        love.graphics.setColor(0.18, 0.26, 0.34, 1)
        love.graphics.setLineWidth(32)
        love.graphics.circle("line", cx, cy, radius + 18)
        love.graphics.setColor(0.34, 0.50, 0.72, 0.17)
        love.graphics.setLineWidth(7)
        love.graphics.circle("line", cx, cy, radius + 8)
        love.graphics.setColor(0.08, 0.10, 0.13, 0.30)
        love.graphics.setLineWidth(9)
        love.graphics.circle("line", cx, cy, radius + 26)
        
        -- Static struts (no animation in cache)
        for i = 1, 6 do
            local angle = (i-1) * (2 * math.pi / 6)
            local innerR = radius + 21
            local outerR = radius + 44
            local x1 = cx + math.cos(angle) * innerR
            local y1 = cy + math.sin(angle) * innerR
            local x2 = cx + math.cos(angle) * outerR
            local y2 = cy + math.sin(angle) * outerR
            love.graphics.setColor(0.22, 0.28, 0.34, 1)
            love.graphics.setLineWidth(13)
            love.graphics.line(x1, y1, x2, y2)
            love.graphics.setColor(0.55, 0.72, 0.98, 0.25)
            love.graphics.setLineWidth(3.5)
            love.graphics.line(x1, y1, x2, y2)
            love.graphics.setColor(0.8, 0.9, 1, 0.12)
            love.graphics.circle("fill", x2, y2, 7)
            love.graphics.setColor(0.28, 0.36, 0.46, 0.32)
            love.graphics.circle("fill", x2, y2, 4.2)
        end
    else
        -- Broken: metallic structure (static)
        love.graphics.setColor(0.22, 0.18, 0.16, 1)
        love.graphics.setLineWidth(32)
        love.graphics.circle("line", cx, cy, radius + 18)
        love.graphics.setColor(0.72, 0.34, 0.34, 0.12)
        love.graphics.setLineWidth(7)
        love.graphics.circle("line", cx, cy, radius + 8)
        love.graphics.setColor(0.11, 0.04, 0.02, 0.20)
        love.graphics.setLineWidth(9)
        love.graphics.circle("line", cx, cy, radius + 26)
        
        -- Static struts (no animation)
        for i = 1, 6 do
            local angle = (i-1) * (2 * math.pi / 6)
            local innerR = radius + 21
            local outerR = radius + 44
            local x1 = cx + math.cos(angle) * innerR
            local y1 = cy + math.sin(angle) * innerR
            local x2 = cx + math.cos(angle) * outerR
            local y2 = cy + math.sin(angle) * outerR
            love.graphics.setColor(0.32, 0.19, 0.18, 1)
            love.graphics.setLineWidth(13)
            love.graphics.line(x1, y1, x2, y2)
            love.graphics.setColor(0.95, 0.55, 0.33, 0.17)
            love.graphics.setLineWidth(3.5)
            love.graphics.line(x1, y1, x2, y2)
            love.graphics.setColor(1, 0.34, 0.16, 0.14)
            love.graphics.circle("fill", x2, y2, 7)
            love.graphics.setColor(0.38, 0.15, 0.12, 0.32)
            love.graphics.circle("fill", x2, y2, 4.2)
        end
    end
    
    love.graphics.setCanvas()
    love.graphics.pop()
    
    return canvas
end

function RenderEffects.drawWarpGates()
    local ECS = require('src.ecs')
    local gateEntities = ECS.getEntitiesWith({"WarpGate", "Position"})
    local time = love.timer.getTime()
    
    for _, gateId in ipairs(gateEntities) do
        local pos = ECS.getComponent(gateId, "Position")
        local coll = ECS.getComponent(gateId, "Collidable")
        local gate = ECS.getComponent(gateId, "WarpGate")
        local active = gate and gate.active or false
        local radius = (coll and coll.radius) or 80
        local cx, cy = pos.x, pos.y
        
        -- Generate cache if needed
        if not warpGateCache.active or not warpGateCache.inactive or warpGateCache.radius ~= radius then
            if warpGateCache.active then warpGateCache.active:release() end
            if warpGateCache.inactive then warpGateCache.inactive:release() end
            warpGateCache.active = generateWarpGateCanvas(true, radius)
            warpGateCache.inactive = generateWarpGateCanvas(false, radius)
            warpGateCache.radius = radius
        end
        
        -- Draw cached static structure
        local canvas = active and warpGateCache.active or warpGateCache.inactive
        local size = (radius + 60) * 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, cx - size/2, cy - size/2)
        
        if active then
            -- Only draw animated parts (much cheaper)
            -- Glowy/energy effects (animated, blue)
            local pulse = 0.28 + 0.16 * math.sin(time * 2.5)
            love.graphics.setColor(0.2, 0.55, 1, pulse)
            love.graphics.setLineWidth(24)
            love.graphics.circle("line", cx, cy, radius + 10)
            love.graphics.setColor(0.4, 0.75, 1, 0.19)
            love.graphics.setLineWidth(12)
            love.graphics.circle("line", cx, cy, radius)
            love.graphics.setColor(0.15, 0.33, 0.6, 0.18)
            love.graphics.circle("fill", cx, cy, radius-12)
            love.graphics.setColor(1, 1, 1, 0.15+0.07*math.sin(time*5))
            love.graphics.setLineWidth(4)
            love.graphics.circle("line", cx, cy, radius-15)
            
            -- Rotating swirl arcs
            for i = 1, 3 do
                local angle = time * 1.1 + i * (2 * math.pi) / 3
                local arcRadius = radius - 22
                local arcX = cx + math.cos(angle) * arcRadius
                local arcY = cy + math.sin(angle) * arcRadius
                love.graphics.setColor(0.6, 0.9, 1, 0.13 + 0.11 * math.abs(math.sin(time*2 + i)))
                love.graphics.setLineWidth(10)
                love.graphics.circle("line", arcX, arcY, 17)
            end
            love.graphics.setColor(0.55, 0.85, 1, 0.19 + 0.09 * math.abs(math.sin(time*1.7)))
            love.graphics.circle("fill", cx, cy, radius*0.42)
        else
            -- Static glow effects for broken gate
            love.graphics.setColor(0.63, 0.19, 0.19, 0.18)
            love.graphics.setLineWidth(24)
            love.graphics.circle("line", cx, cy, radius + 10)
            love.graphics.setColor(1, 0.32, 0.16, 0.14)
            love.graphics.setLineWidth(12)
            love.graphics.circle("line", cx, cy, radius)
            love.graphics.setColor(0.77, 0.17, 0.07, 0.18)
            love.graphics.circle("fill", cx, cy, radius-12)
            love.graphics.setColor(1, 0.92, 0.38, 0.10)
            love.graphics.setLineWidth(4)
            love.graphics.circle("line", cx, cy, radius-15)
            love.graphics.setColor(1, 0.27, 0.14, 0.13)
            love.graphics.circle("fill", cx, cy, radius*0.37)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1,1)
end

return RenderEffects
