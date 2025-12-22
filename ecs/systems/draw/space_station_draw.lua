local Utils = require("ecs.systems.draw.render_utils")

local SpaceStationDraw = {}

local function drawDockRingIfNear(ctx, stationX, stationY, dockingRange)
    local range = dockingRange or 0
    if range <= 0 then
        return
    end

    local baseAlpha = 0.08
    local brightAlpha = 0.85
    local t = 0

    local playerShip = ctx and ctx.playerShip
    local body = playerShip and playerShip.physics_body and playerShip.physics_body.body
    if body then
        local px, py = body:getPosition()
        local dx, dy = px - stationX, py - stationY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= range then
            t = 1
        else
            local falloffRange = range * 1.05
            t = math.max(0, math.min(1, 1 - dist / falloffRange))
            t = t * t -- smoother ease
        end
    end

    local alpha = baseAlpha + (brightAlpha - baseAlpha) * t

    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.20, 0.85, 1.00, alpha)
    love.graphics.circle("line", 0, 0, range)
    love.graphics.pop()
end

local function drawStructuralRing(radius, lineWidth, color)
    love.graphics.push("all")
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.circle("line", 0, 0, radius)
    love.graphics.pop()
end

local function drawRadialBeam(innerR, outerR, angle, width, color)
    love.graphics.push("all")
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.setLineWidth(width)
    local x1 = math.cos(angle) * innerR
    local y1 = math.sin(angle) * innerR
    local x2 = math.cos(angle) * outerR
    local y2 = math.sin(angle) * outerR
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.pop()
end

function SpaceStationDraw.draw(ctx, e, body, shape, x, y, angle)
    local radius = (e.space_station and e.space_station.radius) or 400
    local dockingPoints = (e.space_station and e.space_station.dockingPoints) or {}

    -- Cull if off-screen (with extra padding for large station)
    if ctx.viewLeft then
        local cullRadius = radius + 150
        if x + cullRadius < ctx.viewLeft - ctx.cullPad or x - cullRadius > ctx.viewRight + ctx.cullPad
            or y + cullRadius < ctx.viewTop - ctx.cullPad or y - cullRadius > ctx.viewBottom + ctx.cullPad then
            return
        end
    end

    local time = love.timer.getTime()

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    -- Main hull (octagon from physics shape)
    love.graphics.push("all")
    love.graphics.setColor(0.16, 0.20, 0.30, 1.0)
    love.graphics.polygon("fill", shape:getPoints())
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(4)
    love.graphics.setColor(0.42, 0.52, 0.70, 0.9)
    love.graphics.polygon("line", shape:getPoints())
    love.graphics.pop()

    -- Outer plate wedges (give depth without full rings)
    love.graphics.push("all")
    love.graphics.setColor(0.24, 0.30, 0.42, 0.9)
    for i = 0, 7 do
        local ang = (i / 8) * math.pi * 2 + math.pi / 8
        local wx1 = math.cos(ang) * radius * 0.78
        local wy1 = math.sin(ang) * radius * 0.78
        local wx2 = math.cos(ang) * radius * 0.52
        local wy2 = math.sin(ang) * radius * 0.52
        love.graphics.setLineWidth(6)
        love.graphics.line(wx1, wy1, wx2, wy2)
    end
    love.graphics.pop()

    -- Radiating trusses (hard mechanical feel)
    for i = 0, 11 do
        local beamAngle = (i / 12) * math.pi * 2
        drawRadialBeam(radius * 0.30, radius * 0.72, beamAngle, 3, { 0.48, 0.60, 0.82, 0.55 })
    end

    -- Mid core plating
    love.graphics.push("all")
    love.graphics.setColor(0.22, 0.28, 0.40, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.55, 0.65, 0.82, 0.7)
    love.graphics.circle("line", 0, 0, radius * 0.55)
    love.graphics.pop()

    -- Sensor fins (four cardinal antennas)
    love.graphics.push("all")
    love.graphics.setColor(0.60, 0.80, 0.95, 0.8)
    love.graphics.setLineWidth(2)
    local finLen = radius * 0.32
    love.graphics.line(-finLen, 0, -radius * 0.05, 0)
    love.graphics.line(finLen, 0, radius * 0.05, 0)
    love.graphics.line(0, -finLen, 0, -radius * 0.05)
    love.graphics.line(0, finLen, 0, radius * 0.05)
    love.graphics.pop()

    -- Command hub and beacon
    love.graphics.push("all")
    love.graphics.setColor(0.32, 0.40, 0.58, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.26)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.65, 0.76, 0.92, 0.9)
    love.graphics.circle("line", 0, 0, radius * 0.26)
    love.graphics.setColor(0.38, 0.48, 0.66, 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.12)
    local beaconPulse = 0.5 + 0.5 * math.sin(time * 3)
    love.graphics.setColor(0.00, 0.95, 0.85, beaconPulse * 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.05)
    love.graphics.setColor(0.00, 1.00, 0.90, beaconPulse * 0.45)
    love.graphics.circle("line", 0, 0, radius * 0.08)
    love.graphics.pop()

    -- Docking distance ring (cyan) only when player is close enough
    drawDockRingIfNear(ctx, x, y, radius * 1.6)

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return SpaceStationDraw
