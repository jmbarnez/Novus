local Utils = require("ecs.systems.draw.render_utils")

local RefineryStationDraw = {}

local function drawDockingBay(radius, angle, dockId, time)
    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.translate(radius, 0)

    -- Docking arm structure (industrial orange)
    love.graphics.push("all")
    love.graphics.setColor(0.50, 0.35, 0.20, 1.0)
    love.graphics.rectangle("fill", -15, -20, 70, 40)
    love.graphics.pop()

    -- Docking arm outline
    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.75, 0.55, 0.30, 0.9)
    love.graphics.rectangle("line", -15, -20, 70, 40)
    love.graphics.pop()

    -- Docking bay opening
    love.graphics.push("all")
    love.graphics.setColor(0.20, 0.15, 0.10, 1.0)
    love.graphics.rectangle("fill", 48, -14, 12, 28)
    love.graphics.pop()

    -- Bay entrance lights (orange glow)
    love.graphics.push("all")
    local blinkOffset = (dockId * 0.3) % 1
    local lightPhase = ((time * 1.5) + blinkOffset) % 1
    local lightAlpha = 0.4 + 0.6 * math.abs(math.sin(lightPhase * math.pi))
    love.graphics.setColor(1.00, 0.60, 0.20, lightAlpha)
    love.graphics.circle("fill", 60, -12, 3)
    love.graphics.circle("fill", 60, 12, 3)
    love.graphics.pop()

    love.graphics.pop()
end

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

    -- Outer ambient glow (orange/amber)
    love.graphics.push("all")
    love.graphics.setColor(0.80, 0.45, 0.15, 0.08)
    love.graphics.circle("fill", 0, 0, radius * 1.3)
    love.graphics.setColor(0.90, 0.50, 0.20, 0.05)
    love.graphics.circle("fill", 0, 0, radius * 1.5)
    love.graphics.pop()

    -- Draw docking bays
    for i, dock in ipairs(dockingPoints) do
        drawDockingBay(radius * 0.88, dock.angle, dock.id, time)
    end

    -- Main station body (hexagon from physics shape)
    love.graphics.push("all")
    love.graphics.setColor(0.28, 0.22, 0.16, 1.0)
    love.graphics.polygon("fill", shape:getPoints())
    love.graphics.pop()

    -- Station hull outline
    love.graphics.push("all")
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.75, 0.55, 0.30, 0.9)
    love.graphics.polygon("line", shape:getPoints())
    love.graphics.pop()

    -- Outer structural ring
    drawStructuralRing(radius * 0.92, 2, { 0.70, 0.50, 0.28, 0.6 })
    drawStructuralRing(radius * 0.80, 2, { 0.60, 0.42, 0.24, 0.5 })

    -- Processing pipes (12 pipes)
    for i = 0, 11 do
        local pipeAngle = (i / 12) * math.pi * 2
        drawProcessingPipe(radius * 0.35, radius * 0.65, pipeAngle, 4, { 0.55, 0.40, 0.25, 0.7 })
    end

    -- Inner processing chamber
    love.graphics.push("all")
    love.graphics.setColor(0.35, 0.28, 0.20, 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.50)
    love.graphics.pop()
    drawStructuralRing(radius * 0.50, 2, { 0.70, 0.50, 0.30, 0.8 })

    -- Furnace core (animated)
    love.graphics.push("all")
    local furnacePulse = 0.6 + 0.4 * math.sin(time * 2)
    love.graphics.setColor(0.40, 0.30, 0.18, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.30)
    love.graphics.setColor(0.80, 0.45, 0.15, furnacePulse * 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.22)
    love.graphics.setColor(1.00, 0.70, 0.30, furnacePulse * 0.7)
    love.graphics.circle("fill", 0, 0, radius * 0.14)
    love.graphics.pop()

    -- Molten core glow
    love.graphics.push("all")
    local coreGlow = 0.5 + 0.5 * math.sin(time * 3)
    love.graphics.setColor(1.00, 0.55, 0.20, coreGlow * 0.8)
    love.graphics.circle("fill", 0, 0, radius * 0.08)
    love.graphics.setColor(1.00, 0.80, 0.40, coreGlow * 0.4)
    love.graphics.circle("fill", 0, 0, radius * 0.12)
    love.graphics.pop()

    -- Vent steam effects
    love.graphics.push("all")
    for i = 0, 5 do
        local ventAngle = (i / 6) * math.pi * 2 + time * 0.2
        local ventDist = radius * 0.65
        local vx = math.cos(ventAngle) * ventDist
        local vy = math.sin(ventAngle) * ventDist
        local steamAlpha = 0.2 + 0.15 * math.sin((time * 4 + i) * math.pi)
        love.graphics.setColor(0.90, 0.85, 0.75, steamAlpha)
        love.graphics.circle("fill", vx, vy, 6)
    end
    love.graphics.pop()

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return RefineryStationDraw
