local Utils = require("ecs.systems.draw.render_utils")

local RefineryStationDraw = {}

local function drawStructuralRing(radius, lineWidth, color)
    love.graphics.push("all")
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.circle("line", 0, 0, radius)
    love.graphics.pop()
end

local function drawProcessingPipe(innerR, outerR, angle, width, color)
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

local function drawDockRingIfNear(ctx, stationX, stationY, dockingRange)
    local range = dockingRange or 0
    if range <= 0 then
        return
    end

    local baseAlpha = 0.10
    local brightAlpha = 0.95
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
    -- Orange docking ring for refinery stations
    love.graphics.setColor(0.95, 0.55, 0.15, alpha)
    love.graphics.circle("line", 0, 0, range)
    love.graphics.pop()
end

function RefineryStationDraw.draw(ctx, e, body, shape, x, y, angle)
    local radius = (e.space_station and e.space_station.radius) or 200
    local dockingPoints = (e.space_station and e.space_station.dockingPoints) or {}

    -- Cull if off-screen
    if ctx.viewLeft then
        local cullRadius = radius + 100
        if x + cullRadius < ctx.viewLeft - ctx.cullPad or x - cullRadius > ctx.viewRight + ctx.cullPad
            or y + cullRadius < ctx.viewTop - ctx.cullPad or y - cullRadius > ctx.viewBottom + ctx.cullPad then
            return
        end
    end

    local time = love.timer.getTime()

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)

    -- Main body: heavy hex plate
    love.graphics.push("all")
    love.graphics.setColor(0.20, 0.18, 0.14, 1.0)
    love.graphics.polygon("fill", shape:getPoints())
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.65, 0.50, 0.32, 0.9)
    love.graphics.polygon("line", shape:getPoints())
    love.graphics.pop()

    -- Reinforced frame (offset hex)
    love.graphics.push("all")
    love.graphics.setColor(0.32, 0.26, 0.20, 0.9)
    love.graphics.setLineWidth(5)
    for i = 1, 6 do
        local ang = (i / 6) * math.pi * 2
        local x1 = math.cos(ang) * radius * 0.92
        local y1 = math.sin(ang) * radius * 0.92
        local x2 = math.cos(ang + math.pi / 3) * radius * 0.92
        local y2 = math.sin(ang + math.pi / 3) * radius * 0.92
        love.graphics.line(x1, y1, x2, y2)
    end
    love.graphics.pop()

    -- Structural ribs (6 heavy beams)
    for i = 0, 5 do
        local ang = (i / 6) * math.pi * 2
        drawProcessingPipe(radius * 0.28, radius * 0.78, ang, 6, { 0.55, 0.40, 0.25, 0.8 })
    end

    -- Fuel/ore tanks (three industrial cylinders)
    love.graphics.push("all")
    love.graphics.setColor(0.40, 0.36, 0.32, 1.0)
    local tankR = radius * 0.18
    local tankOffset = radius * 0.42
    local tankPositions = {
        { -tankOffset, -radius * 0.08 },
        { tankOffset, -radius * 0.12 },
        { 0, radius * 0.26 },
    }
    for _, pos in ipairs(tankPositions) do
        love.graphics.circle("fill", pos[1], pos[2], tankR)
        love.graphics.setColor(0.75, 0.60, 0.35, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", pos[1], pos[2], tankR)
        love.graphics.setColor(0.40, 0.36, 0.32, 1.0)
    end
    love.graphics.pop()

    -- Conveyor deck (horizontal band)
    love.graphics.push("all")
    love.graphics.setColor(0.18, 0.16, 0.12, 0.9)
    love.graphics.rectangle("fill", -radius * 0.70, -radius * 0.10, radius * 1.40, radius * 0.20, 6)
    love.graphics.setColor(0.70, 0.55, 0.32, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -radius * 0.70, -radius * 0.10, radius * 1.40, radius * 0.20, 6)
    love.graphics.pop()

    -- Heat exchanger fins (8 short blades)
    love.graphics.push("all")
    love.graphics.setColor(0.80, 0.65, 0.38, 0.85)
    love.graphics.setLineWidth(3)
    for i = 0, 7 do
        local ang = (i / 8) * math.pi * 2 + math.pi / 8
        local inner = radius * 0.20
        local outer = radius * 0.34
        love.graphics.line(
            math.cos(ang) * inner, math.sin(ang) * inner,
            math.cos(ang) * outer, math.sin(ang) * outer
        )
    end
    love.graphics.pop()

    -- Furnace core (layered, animated glow)
    local furnacePulse = 0.6 + 0.4 * math.sin(time * 2)
    love.graphics.push("all")
    love.graphics.setColor(0.30, 0.22, 0.16, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.26)
    love.graphics.setColor(0.80, 0.45, 0.18, furnacePulse * 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.20)
    love.graphics.setColor(1.00, 0.72, 0.32, furnacePulse * 0.7)
    love.graphics.circle("fill", 0, 0, radius * 0.14)
    love.graphics.setColor(1.00, 0.85, 0.55, furnacePulse * 0.5)
    love.graphics.circle("line", 0, 0, radius * 0.20)
    love.graphics.pop()

    -- Vent steam effects (retain but tie to new geometry)
    love.graphics.push("all")
    for i = 0, 5 do
        local ventAngle = (i / 6) * math.pi * 2 + time * 0.2
        local ventDist = radius * 0.66
        local vx = math.cos(ventAngle) * ventDist
        local vy = math.sin(ventAngle) * ventDist
        local steamAlpha = 0.18 + 0.14 * math.sin((time * 4 + i) * math.pi)
        love.graphics.setColor(0.92, 0.88, 0.82, steamAlpha)
        love.graphics.circle("fill", vx, vy, 6)
    end
    love.graphics.pop()

    -- Docking distance ring (cyan) only when player is close enough
    drawDockRingIfNear(ctx, x, y, radius * 1.4)

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return RefineryStationDraw
