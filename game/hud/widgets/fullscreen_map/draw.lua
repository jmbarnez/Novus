--- Fullscreen Map Drawing functions
local M = {}

local Theme = require("game.theme")
local Rect = require("util.rect")
local MapView = require("game.hud.widgets.fullscreen_map_view")

local pointInRect = Rect.pointInRect

--- Draw the grid overlay
---@param ctx table HUD context
---@param view table View data
function M.drawGrid(ctx, view)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors
    local fm = hudTheme.fullscreenMap or {}
    local dr = view.drawRect

    local targetPx = fm.gridTargetPx or 110
    local rawWorld = targetPx / view.scale
    local step = MapView.niceStep(rawWorld)

    local x0 = math.floor(view.left / step) * step
    local y0 = math.floor(view.top / step) * step
    local x1 = view.left + view.viewW
    local y1 = view.top + view.viewH

    love.graphics.setColor(colors.minimapGrid[1], colors.minimapGrid[2], colors.minimapGrid[3], 0.16)

    local x = x0
    while x <= x1 do
        local sx = dr.x + (x - view.left) * view.scale
        love.graphics.line(sx, dr.y, sx, dr.y + dr.h)
        x = x + step
    end

    local y = y0
    while y <= y1 do
        local sy = dr.y + (y - view.top) * view.scale
        love.graphics.line(dr.x, sy, dr.x + dr.w, sy)
        y = y + step
    end

    local labelStep = step * 2
    local lx = math.floor(view.left / labelStep) * labelStep
    local ly = math.floor(view.top / labelStep) * labelStep

    local infoX = dr.x + (fm.gridInfoOffsetX or 6)
    local infoY = dr.y + (fm.gridInfoOffsetY or 6)
    local infoW = fm.gridInfoW or 176
    local infoH = fm.gridInfoH or 38
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", infoX, infoY, infoW, infoH)

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.85)
    local textX = dr.x + (fm.gridInfoTextX or 12)
    love.graphics.print(string.format("Grid %.0f", step), textX, dr.y + (fm.gridInfoTextY1 or 10))
    love.graphics.print(string.format("X: %.0f..%.0f", view.left, view.left + view.viewW), textX,
        dr.y + (fm.gridInfoTextY2 or 24))
    love.graphics.print(string.format("Y: %.0f..%.0f", view.top, view.top + view.viewH), textX,
        dr.y + (fm.gridInfoTextY3 or 38))

    local xLabel = lx
    while xLabel <= x1 do
        local sx = dr.x + (xLabel - view.left) * view.scale
        if sx >= dr.x and sx <= dr.x + dr.w then
            local t = string.format("%.0f", xLabel)
            love.graphics.setColor(0, 0, 0, 0.65)
            love.graphics.print(t, sx + 1, dr.y + 1)
            love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.55)
            love.graphics.print(t, sx, dr.y)
        end
        xLabel = xLabel + labelStep
    end

    local yLabel = ly
    while yLabel <= y1 do
        local sy = dr.y + (yLabel - view.top) * view.scale
        if sy >= dr.y and sy <= dr.y + dr.h then
            local t = string.format("%.0f", yLabel)
            love.graphics.setColor(0, 0, 0, 0.65)
            love.graphics.print(t, dr.x + 1, sy + 1)
            love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.55)
            love.graphics.print(t, dr.x, sy)
        end
        yLabel = yLabel + labelStep
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Draw the player heading indicator
---@param ctx table HUD context
---@param view table View data
function M.drawHeading(ctx, view)
    if not ctx or not ctx.hasShip or not ctx.shipAngle then
        return
    end

    local theme = (ctx and ctx.theme) or Theme
    local colors = theme.hud.colors

    local sx, sy = MapView.worldToScreen(view, ctx.x or 0, ctx.y or 0)

    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(ctx.shipAngle)

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.polygon("fill", 10, 0, -7, 6, -4, 0, -7, -6)

    love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.95)
    love.graphics.polygon("fill", 9, 0, -6, 5, -3, 0, -6, -5)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

--- Draw the waypoint marker
---@param ctx table HUD context
---@param view table View data
---@param mapUi table Map UI state
function M.drawWaypoint(ctx, view, mapUi)
    if not mapUi or not mapUi.waypointX or not mapUi.waypointY then
        return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors
    local fm = hudTheme.fullscreenMap or {}

    local sx, sy = MapView.worldToScreen(view, mapUi.waypointX, mapUi.waypointY)

    if sx < view.drawRect.x or sx > (view.drawRect.x + view.drawRect.w) or sy < view.drawRect.y or sy > (view.drawRect.y + view.drawRect.h) then
        return
    end

    love.graphics.setColor(1, 1, 1, fm.waypointLineAlpha or 0.18)
    if ctx and ctx.hasShip then
        local px, py = MapView.worldToScreen(view, ctx.x or 0, ctx.y or 0)
        love.graphics.line(px, py, sx, sy)
    end

    love.graphics.setColor(colors.accentSoft[1], colors.accentSoft[2], colors.accentSoft[3], colors.accentSoft[4])
    love.graphics.setLineWidth(fm.waypointCrossLineWidth or 2)
    local half = fm.waypointCrossHalf or 8
    love.graphics.line(sx - half, sy, sx + half, sy)
    love.graphics.line(sx, sy - half, sx, sy + half)
    love.graphics.setLineWidth(1)

    local shadowA = fm.waypointLabelShadowAlpha or 0.75
    love.graphics.setColor(0, 0, 0, shadowA)
    local label = string.format("WAYPOINT %.0f, %.0f", mapUi.waypointX, mapUi.waypointY)
    local ox = fm.waypointLabelOffsetX or 10
    local oy = fm.waypointLabelOffsetY or -10
    local shOff = fm.waypointLabelShadowOffset or 1
    love.graphics.print(label, sx + ox + shOff, sy + oy + shOff)
    love.graphics.setColor(1, 1, 1, fm.waypointLabelTextAlpha or 0.85)
    love.graphics.print(label, sx + ox, sy + oy)

    love.graphics.setColor(1, 1, 1, 1)
end

--- Draw the legend panel
---@param ctx table HUD context
---@param legendRect table Legend rectangle
function M.drawLegend(ctx, legendRect)
    if not legendRect then
        return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors

    love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], 0.65)
    love.graphics.rectangle("fill", legendRect.x, legendRect.y, legendRect.w, legendRect.h)

    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], 0.55)
    love.graphics.rectangle("line", legendRect.x, legendRect.y, legendRect.w, legendRect.h)

    local fm = hudTheme.fullscreenMap or {}
    local lg = fm.legend or {}

    local x = legendRect.x + (lg.padX or 12)
    local y = legendRect.y + (lg.padY or 10)

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    love.graphics.print("MAP", x, y)
    y = y + 22

    local function entry(label, c)
        local sw = lg.swatchSize or 12
        local insetY = lg.swatchInsetY or 4
        love.graphics.setColor(c[1], c[2], c[3], lg.swatchAlpha or 0.9)
        love.graphics.rectangle("fill", x, y + insetY, sw, sw)
        love.graphics.setColor(1, 1, 1, lg.swatchBorderAlpha or 0.35)
        love.graphics.rectangle("line", x, y + insetY, sw, sw)
        love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
        love.graphics.print(label, x + (lg.textX or 18), y)
        y = y + (lg.rowGap or 18)
    end

    entry("Player",
        { (lg.player and lg.player[1]) or 0.20, (lg.player and lg.player[2]) or 0.65, (lg.player and lg.player[3]) or
        1.00 })
    entry("Asteroid",
        { (lg.asteroid and lg.asteroid[1]) or 1.00, (lg.asteroid and lg.asteroid[2]) or 1.00, (lg.asteroid and lg.asteroid[3]) or
        1.00 })
    entry("Pickup",
        { (lg.pickup and lg.pickup[1]) or 0.35, (lg.pickup and lg.pickup[2]) or 1.00, (lg.pickup and lg.pickup[3]) or
        0.45 })
    entry("Ship",
        { (lg.ship and lg.ship[1]) or 1.00, (lg.ship and lg.ship[2]) or 0.65, (lg.ship and lg.ship[3]) or 0.20 })

    y = y + 14

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.85)
    love.graphics.print("Controls", x, y)
    y = y + 18

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.75)
    love.graphics.print("M / Esc: close", x, y)
    y = y + 16
    love.graphics.print("Wheel: zoom", x, y)
    y = y + 16
    love.graphics.print("Drag: pan", x, y)
    y = y + 16
    love.graphics.print("Right-click: clear WP", x, y)
    y = y + 16
    love.graphics.print("Click: waypoint", x, y)

    local btn = MapView.legendButtonRect(legendRect)
    if btn then
        local mx, my = love.mouse.getPosition()
        local hover = pointInRect(mx, my, btn)

        love.graphics.setColor(0, 0, 0, hover and 0.55 or 0.35)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(1, 1, 1, hover and 0.45 or 0.25)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)

        local label = "CENTER ON PLAYER"
        local font = love.graphics.getFont()
        local tw = font:getWidth(label)
        local th = font:getHeight()

        love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.9)
        love.graphics.print(label, btn.x + (btn.w - tw) * 0.5, btn.y + (btn.h - th) * 0.5)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Draw the main map content (entities, player, etc.)
---@param ctx table HUD context
---@param view table View data
function M.drawMapContent(ctx, view)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors

    local dr = view.drawRect

    love.graphics.setColor(colors.minimapBg[1], colors.minimapBg[2], colors.minimapBg[3], 0.75)
    love.graphics.rectangle("fill", dr.x, dr.y, dr.w, dr.h)

    M.drawGrid(ctx, view)

    local world = ctx.world

    if world and world.query then
        local maxAsteroids = 1200
        local drawn = 0
        world:query({ "asteroid", "physics_body" }, function(e)
            if drawn >= maxAsteroids then
                return
            end

            local body = e.physics_body and e.physics_body.body
            if not body then
                return
            end

            local wx, wy = body:getPosition()
            if wx < view.left or wx > (view.left + view.viewW) or wy < view.top or wy > (view.top + view.viewH) then
                return
            end

            local sx, sy = MapView.worldToScreen(view, wx, wy)

            local ac = colors.asteroid or { 1, 1, 1, 0.45 }
            love.graphics.setColor(ac[1], ac[2], ac[3], ac[4])
            love.graphics.rectangle("fill", sx - 1, sy - 1, 2, 2)

            drawn = drawn + 1
        end)

        local maxPickups = 600
        local drawnP = 0
        world:query({ "pickup", "physics_body" }, function(e)
            if drawnP >= maxPickups then
                return
            end

            local body = e.physics_body and e.physics_body.body
            if not body then
                return
            end

            local wx, wy = body:getPosition()
            if wx < view.left or wx > (view.left + view.viewW) or wy < view.top or wy > (view.top + view.viewH) then
                return
            end

            local sx, sy = MapView.worldToScreen(view, wx, wy)

            local pc = colors.pickup or { 0.35, 1.0, 0.45, 0.85 }
            love.graphics.setColor(pc[1], pc[2], pc[3], pc[4])
            love.graphics.rectangle("fill", sx - 2, sy - 2, 4, 4)
            drawnP = drawnP + 1
        end)

        local maxShips = 64
        local drawnS = 0
        world:query({ "ship", "physics_body" }, function(e)
            if drawnS >= maxShips then
                return
            end

            local body = e.physics_body and e.physics_body.body
            if not body then
                return
            end

            local wx, wy = body:getPosition()
            if wx < view.left or wx > (view.left + view.viewW) or wy < view.top or wy > (view.top + view.viewH) then
                return
            end

            local sx, sy = MapView.worldToScreen(view, wx, wy)

            local sc = colors.ship or { 1.0, 0.65, 0.20, 0.55 }
            love.graphics.setColor(sc[1], sc[2], sc[3], sc[4])
            love.graphics.circle("fill", sx, sy, 3)
            drawnS = drawnS + 1
        end)
    end

    if ctx.hasShip then
        local sx, sy = MapView.worldToScreen(view, ctx.x or 0, ctx.y or 0)

        love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.25)
        love.graphics.circle("fill", sx, sy, 10)

        love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.7)
        love.graphics.circle("fill", sx, sy, 5)

        love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 1.0)
        love.graphics.circle("fill", sx, sy, 3)

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", sx, sy, 1)
    end

    M.drawHeading(ctx, view)
    M.drawWaypoint(ctx, view, view.mapUi)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], 0.65)
    love.graphics.rectangle("line", dr.x, dr.y, dr.w, dr.h)

    love.graphics.setColor(1, 1, 1, 1)
end

return M
