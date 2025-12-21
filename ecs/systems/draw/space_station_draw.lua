local Utils = require("ecs.systems.draw.render_utils")

local SpaceStationDraw = {}

local function drawDockingBay(radius, angle, dockId, time)
    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.translate(radius, 0)

    -- Docking arm structure
    love.graphics.push("all")
    love.graphics.setColor(0.35, 0.40, 0.50, 1.0)
    love.graphics.rectangle("fill", -20, -25, 100, 50)
    love.graphics.pop()

    -- Docking arm outline
    love.graphics.push("all")
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.50, 0.60, 0.75, 0.9)
    love.graphics.rectangle("line", -20, -25, 100, 50)
    love.graphics.pop()

    -- Docking bay opening
    love.graphics.push("all")
    love.graphics.setColor(0.15, 0.20, 0.30, 1.0)
    love.graphics.rectangle("fill", 70, -18, 15, 36)
    love.graphics.pop()

    -- Bay entrance lights
    love.graphics.push("all")
    local blinkOffset = (dockId * 0.3) % 1
    local lightPhase = ((time * 1.5) + blinkOffset) % 1
    local lightAlpha = 0.4 + 0.6 * math.abs(math.sin(lightPhase * math.pi))
    love.graphics.setColor(0.00, 1.00, 0.70, lightAlpha)
    love.graphics.circle("fill", 85, -15, 4)
    love.graphics.circle("fill", 85, 15, 4)
    love.graphics.pop()

    -- Guide lights along the arm
    love.graphics.push("all")
    local guidePhase = ((time * 2) + blinkOffset) % 1
    for i = 0, 2 do
        local gx = 10 + i * 25
        local ga = (guidePhase + i * 0.2) % 1
        local gAlpha = 0.3 + 0.5 * math.sin(ga * math.pi)
        love.graphics.setColor(0.00, 0.80, 0.90, gAlpha)
        love.graphics.circle("fill", gx, -22, 3)
        love.graphics.circle("fill", gx, 22, 3)
    end
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

    -- Outer ambient glow
    love.graphics.push("all")
    love.graphics.setColor(0.20, 0.40, 0.70, 0.08)
    love.graphics.circle("fill", 0, 0, radius * 1.4)
    love.graphics.setColor(0.25, 0.50, 0.80, 0.05)
    love.graphics.circle("fill", 0, 0, radius * 1.6)
    love.graphics.pop()

    -- Draw docking bays
    for i, dock in ipairs(dockingPoints) do
        drawDockingBay(radius * 0.92, dock.angle, dock.id, time)
    end

    -- Main station body (octagon from physics shape)
    love.graphics.push("all")
    love.graphics.setColor(0.18, 0.22, 0.32, 1.0)
    love.graphics.polygon("fill", shape:getPoints())
    love.graphics.pop()

    -- Station hull outline
    love.graphics.push("all")
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(4)
    love.graphics.setColor(0.40, 0.50, 0.65, 0.9)
    love.graphics.polygon("line", shape:getPoints())
    love.graphics.pop()

    -- Outer structural ring
    drawStructuralRing(radius * 0.95, 3, { 0.50, 0.60, 0.75, 0.6 })
    drawStructuralRing(radius * 0.85, 2, { 0.40, 0.50, 0.65, 0.5 })

    -- Mid section panels
    love.graphics.push("all")
    love.graphics.setColor(0.25, 0.30, 0.42, 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.70)
    love.graphics.pop()
    drawStructuralRing(radius * 0.70, 3, { 0.55, 0.65, 0.80, 0.7 })

    -- Radial support beams (16 beams)
    for i = 0, 15 do
        local beamAngle = (i / 16) * math.pi * 2
        drawRadialBeam(radius * 0.35, radius * 0.70, beamAngle, 3, { 0.45, 0.55, 0.70, 0.6 })
    end

    -- Inner ring with windows
    love.graphics.push("all")
    love.graphics.setColor(0.22, 0.28, 0.40, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.50)
    love.graphics.pop()
    drawStructuralRing(radius * 0.50, 2, { 0.50, 0.60, 0.78, 0.8 })

    -- Window lights on inner ring
    love.graphics.push("all")
    local windowRing = radius * 0.45
    for i = 0, 23 do
        local wAngle = (i / 24) * math.pi * 2
        local wx = math.cos(wAngle) * windowRing
        local wy = math.sin(wAngle) * windowRing
        local wFlicker = 0.6 + 0.4 * math.sin((time * 0.5 + i * 0.2) * math.pi)
        love.graphics.setColor(0.90, 0.85, 0.60, wFlicker * 0.7)
        love.graphics.circle("fill", wx, wy, 5)
    end
    love.graphics.pop()

    -- Central command hub
    love.graphics.push("all")
    love.graphics.setColor(0.30, 0.38, 0.55, 1.0)
    love.graphics.circle("fill", 0, 0, radius * 0.25)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.60, 0.70, 0.85, 0.9)
    love.graphics.circle("line", 0, 0, radius * 0.25)
    love.graphics.pop()

    -- Command hub inner details
    love.graphics.push("all")
    love.graphics.setColor(0.35, 0.45, 0.60, 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.12)
    love.graphics.pop()

    -- Central beacon
    love.graphics.push("all")
    local beaconPulse = 0.5 + 0.5 * math.sin(time * 3)
    love.graphics.setColor(0.00, 0.95, 0.85, beaconPulse * 0.9)
    love.graphics.circle("fill", 0, 0, radius * 0.05)
    love.graphics.setColor(0.00, 1.00, 0.90, beaconPulse * 0.4)
    love.graphics.circle("fill", 0, 0, radius * 0.08)
    love.graphics.pop()

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return SpaceStationDraw
