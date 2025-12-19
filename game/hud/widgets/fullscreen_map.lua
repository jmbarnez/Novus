local Theme = require("game.theme")
local MathUtil = require("util.math")

local function pointInRect(px, py, r)
  return px >= r.x and px <= (r.x + r.w) and py >= r.y and py <= (r.y + r.h)
end

local function makeFullscreenMap()
  local self = {
    dragging = false,
    dragStart = nil,
    dragStartCenter = nil,
    dragMoved = false,
  }

  local function getMapUi(ctx)
    local world = ctx and ctx.world
    return world and world:getResource("map_ui")
  end

  local function getUiCapture(ctx)
    local world = ctx and ctx.world
    return world and world:getResource("ui_capture")
  end

  local function setOpen(ctx, open)
    local mapUi = getMapUi(ctx)
    if not mapUi then
      return
    end

    mapUi.open = open and true or false

    if mapUi.open then
      local sector = ctx and ctx.sector
      if sector then
        mapUi.zoom = mapUi.zoom or 1.0
        mapUi.centerX = mapUi.centerX or (ctx.x or (sector.width * 0.5))
        mapUi.centerY = mapUi.centerY or (ctx.y or (sector.height * 0.5))
      end
    end

    local uiCapture = getUiCapture(ctx)
    if uiCapture then
      uiCapture.active = mapUi.open
    end
  end

  local function clampCenter(sector, centerX, centerY, viewW, viewH)
    if not sector then
      return centerX, centerY
    end

    local halfW = viewW * 0.5
    local halfH = viewH * 0.5

    if viewW >= sector.width then
      centerX = sector.width * 0.5
    else
      centerX = MathUtil.clamp(centerX, halfW, sector.width - halfW)
    end

    if viewH >= sector.height then
      centerY = sector.height * 0.5
    else
      centerY = MathUtil.clamp(centerY, halfH, sector.height - halfH)
    end

    return centerX, centerY
  end

  local function computeLayout(ctx)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local screenW = ctx and ctx.screenW or 0
    local screenH = ctx and ctx.screenH or 0

    local margin = (hudTheme.layout and hudTheme.layout.margin) or 16
    local gap = (hudTheme.layout and hudTheme.layout.stackGap) or 18

    local legendW = 260

    local mapRect = {
      x = margin,
      y = margin,
      w = screenW - margin * 2 - legendW - gap,
      h = screenH - margin * 2,
    }

    if mapRect.w < 200 then
      mapRect.w = screenW - margin * 2
      legendW = 0
    end

    local legendRect
    if legendW > 0 then
      legendRect = {
        x = mapRect.x + mapRect.w + gap,
        y = mapRect.y,
        w = legendW,
        h = mapRect.h,
      }
    end

    return mapRect, legendRect
  end

  local function computeView(ctx, mapRect)
    local mapUi = getMapUi(ctx)
    local sector = ctx and ctx.sector

    if not mapUi or not sector or sector.width <= 0 or sector.height <= 0 then
      return nil
    end

    local zoom = mapUi.zoom or 1.0
    zoom = MathUtil.clamp(zoom, 1.0, 20.0)
    mapUi.zoom = zoom

    local viewW = sector.width / zoom
    local viewH = sector.height / zoom

    local scale = math.min(mapRect.w / viewW, mapRect.h / viewH)
    local drawW = viewW * scale
    local drawH = viewH * scale

    local drawRect = {
      x = mapRect.x + (mapRect.w - drawW) * 0.5,
      y = mapRect.y + (mapRect.h - drawH) * 0.5,
      w = drawW,
      h = drawH,
      scale = scale,
      viewW = viewW,
      viewH = viewH,
    }

    mapUi.centerX = mapUi.centerX or (ctx.x or (sector.width * 0.5))
    mapUi.centerY = mapUi.centerY or (ctx.y or (sector.height * 0.5))

    mapUi.centerX, mapUi.centerY = clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)

    local left = mapUi.centerX - viewW * 0.5
    local top = mapUi.centerY - viewH * 0.5

    return {
      mapUi = mapUi,
      sector = sector,
      drawRect = drawRect,
      left = left,
      top = top,
      scale = scale,
      viewW = viewW,
      viewH = viewH,
      zoom = zoom,
    }
  end

  local function worldToScreen(view, wx, wy)
    local dr = view.drawRect
    local sx = dr.x + (wx - view.left) * view.scale
    local sy = dr.y + (wy - view.top) * view.scale
    return sx, sy
  end

  local function screenToWorld(view, sx, sy)
    local dr = view.drawRect
    local wx = view.left + ((sx - dr.x) / view.scale)
    local wy = view.top + ((sy - dr.y) / view.scale)
    return wx, wy
  end

  local function niceStep(raw)
    if raw <= 0 then
      return 1
    end

    local p = 10 ^ math.floor(math.log(raw) / math.log(10))
    local n = raw / p

    if n <= 1 then
      return 1 * p
    elseif n <= 2 then
      return 2 * p
    elseif n <= 5 then
      return 5 * p
    end

    return 10 * p
  end

  local function drawGrid(ctx, view)
    local theme = (ctx and ctx.theme) or Theme
    local colors = theme.hud.colors
    local dr = view.drawRect

    local targetPx = 110
    local rawWorld = targetPx / view.scale
    local step = niceStep(rawWorld)

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

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", dr.x + 6, dr.y + 6, 176, 38)

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.85)
    love.graphics.print(string.format("Grid %.0f", step), dr.x + 12, dr.y + 10)
    love.graphics.print(string.format("X: %.0f..%.0f", view.left, view.left + view.viewW), dr.x + 12, dr.y + 24)
    love.graphics.print(string.format("Y: %.0f..%.0f", view.top, view.top + view.viewH), dr.x + 12, dr.y + 38)

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

  local function drawHeading(ctx, view)
    if not ctx or not ctx.hasShip or not ctx.shipAngle then
      return
    end

    local theme = (ctx and ctx.theme) or Theme
    local colors = theme.hud.colors

    local sx, sy = worldToScreen(view, ctx.x or 0, ctx.y or 0)

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

  local function drawWaypoint(ctx, view)
    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.waypointX or not mapUi.waypointY then
      return
    end

    local sx, sy = worldToScreen(view, mapUi.waypointX, mapUi.waypointY)

    if sx < view.drawRect.x or sx > (view.drawRect.x + view.drawRect.w) or sy < view.drawRect.y or sy > (view.drawRect.y + view.drawRect.h) then
      return
    end

    love.graphics.setColor(1, 1, 1, 0.18)
    if ctx and ctx.hasShip then
      local px, py = worldToScreen(view, ctx.x or 0, ctx.y or 0)
      love.graphics.line(px, py, sx, sy)
    end

    love.graphics.setColor(1.0, 0.35, 0.95, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.line(sx - 8, sy, sx + 8, sy)
    love.graphics.line(sx, sy - 8, sx, sy + 8)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0, 0, 0, 0.75)
    local label = string.format("WAYPOINT %.0f, %.0f", mapUi.waypointX, mapUi.waypointY)
    love.graphics.print(label, sx + 10 + 1, sy - 10 + 1)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(label, sx + 10, sy - 10)

    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawLegend(ctx, legendRect)
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

    local x = legendRect.x + 12
    local y = legendRect.y + 10

    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
    love.graphics.print("MAP", x, y)
    y = y + 22

    local function entry(label, r, g, b)
      love.graphics.setColor(r, g, b, 0.9)
      love.graphics.rectangle("fill", x, y + 4, 12, 12)
      love.graphics.setColor(1, 1, 1, 0.35)
      love.graphics.rectangle("line", x, y + 4, 12, 12)
      love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
      love.graphics.print(label, x + 18, y)
      y = y + 18
    end

    entry("Player", 0.20, 0.65, 1.00)
    entry("Asteroid", 1, 1, 1)
    entry("Pickup", 0.35, 1.0, 0.45)
    entry("Ship", 1.0, 0.65, 0.20)

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

    local btn = {
      x = legendRect.x + 12,
      y = legendRect.y + legendRect.h - 44,
      w = legendRect.w - 24,
      h = 30,
    }

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

    love.graphics.setColor(1, 1, 1, 1)
  end

  local function drawMap(ctx, view)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors

    local dr = view.drawRect

    love.graphics.setColor(colors.minimapBg[1], colors.minimapBg[2], colors.minimapBg[3], 0.75)
    love.graphics.rectangle("fill", dr.x, dr.y, dr.w, dr.h)

    drawGrid(ctx, view)

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

        local sx, sy = worldToScreen(view, wx, wy)

        love.graphics.setColor(colors.minimapGrid[1], colors.minimapGrid[2], colors.minimapGrid[3], 0.45)
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

        local sx, sy = worldToScreen(view, wx, wy)

        love.graphics.setColor(0.35, 1.0, 0.45, 0.85)
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

        local sx, sy = worldToScreen(view, wx, wy)

        love.graphics.setColor(1.0, 0.65, 0.20, 0.55)
        love.graphics.circle("fill", sx, sy, 3)
        drawnS = drawnS + 1
      end)
    end

    if ctx.hasShip then
      local sx, sy = worldToScreen(view, ctx.x or 0, ctx.y or 0)

      love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.25)
      love.graphics.circle("fill", sx, sy, 10)

      love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.7)
      love.graphics.circle("fill", sx, sy, 5)

      love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 1.0)
      love.graphics.circle("fill", sx, sy, 3)

      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.circle("fill", sx, sy, 1)
    end

    drawHeading(ctx, view)
    drawWaypoint(ctx, view)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], 0.65)
    love.graphics.rectangle("line", dr.x, dr.y, dr.w, dr.h)

    love.graphics.setColor(1, 1, 1, 1)
  end

  function self.draw(ctx)
    local mapUi = getMapUi(ctx)
    if not ctx or not mapUi or not mapUi.open then
      return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local mapRect, legendRect = computeLayout(ctx)
    local view = computeView(ctx, mapRect)
    if not view then
      return
    end

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, ctx.screenW or 0, ctx.screenH or 0)

    drawMap(ctx, view)
    drawLegend(ctx, legendRect)

    local font = love.graphics.getFont()
    local header = string.format("ZOOM %.1fx", view.zoom)

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(header, mapRect.x + 1, mapRect.y - font:getHeight() - 2 + 1)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(header, mapRect.x, mapRect.y - font:getHeight() - 2)

    love.graphics.setColor(1, 1, 1, 1)
  end

  function self.keypressed(ctx, key)
    local mapUi = getMapUi(ctx)
    if not mapUi then
      return false
    end

    if key == "m" then
      setOpen(ctx, not mapUi.open)
      return true
    end

    if not mapUi.open then
      return false
    end

    if key == "escape" then
      setOpen(ctx, false)
      return true
    end

    if key == "=" or key == "kp+" then
      mapUi.zoom = MathUtil.clamp((mapUi.zoom or 1.0) * 1.12, 1.0, 20.0)
      return true
    end

    if key == "-" or key == "kp-" then
      mapUi.zoom = MathUtil.clamp((mapUi.zoom or 1.0) / 1.12, 1.0, 20.0)
      return true
    end

    local sector = ctx and ctx.sector
    if not sector then
      return true
    end

    local zoom = mapUi.zoom or 1.0
    local viewW = sector.width / zoom
    local viewH = sector.height / zoom

    local nudge = math.max(50, math.min(viewW, viewH) * 0.08)

    if key == "left" or key == "a" then
      mapUi.centerX = (mapUi.centerX or (sector.width * 0.5)) - nudge
    elseif key == "right" or key == "d" then
      mapUi.centerX = (mapUi.centerX or (sector.width * 0.5)) + nudge
    elseif key == "up" or key == "w" then
      mapUi.centerY = (mapUi.centerY or (sector.height * 0.5)) - nudge
    elseif key == "down" or key == "s" then
      mapUi.centerY = (mapUi.centerY or (sector.height * 0.5)) + nudge
    else
      return true
    end

    mapUi.centerX, mapUi.centerY = clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)

    return true
  end

  function self.mousepressed(ctx, x, y, button)
    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.open then
      return false
    end

    local mapRect, legendRect = computeLayout(ctx)
    local view = computeView(ctx, mapRect)
    if not view then
      return true
    end

    if button == 2 then
      mapUi.waypointX = nil
      mapUi.waypointY = nil
      return true
    end

    if button ~= 1 then
      return true
    end

    if legendRect and pointInRect(x, y, legendRect) then
      local btn = {
        x = legendRect.x + 12,
        y = legendRect.y + legendRect.h - 44,
        w = legendRect.w - 24,
        h = 30,
      }

      if pointInRect(x, y, btn) and ctx.hasShip then
        mapUi.centerX = ctx.x
        mapUi.centerY = ctx.y
      end

      return true
    end

    if not pointInRect(x, y, view.drawRect) then
      return true
    end

    self.dragging = true
    self.dragStart = { x = x, y = y }
    self.dragStartCenter = { x = mapUi.centerX, y = mapUi.centerY }
    self.dragMoved = false

    return true
  end

  function self.mousereleased(ctx, x, y, button)
    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.open then
      return false
    end

    if button == 1 and self.dragging then
      local mapRect = computeLayout(ctx)
      local view = computeView(ctx, mapRect)
      if view and (not self.dragMoved) and pointInRect(x, y, view.drawRect) then
        local wx, wy = screenToWorld(view, x, y)
        mapUi.waypointX = MathUtil.clamp(wx, 0, (view.sector and view.sector.width) or wx)
        mapUi.waypointY = MathUtil.clamp(wy, 0, (view.sector and view.sector.height) or wy)
      end

      self.dragging = false
      self.dragStart = nil
      self.dragStartCenter = nil
      self.dragMoved = false
      return true
    end

    return true
  end

  function self.mousemoved(ctx, x, y, dx, dy)
    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.open or not self.dragging then
      return false
    end

    if math.abs(dx) + math.abs(dy) > 2 then
      self.dragMoved = true
    end

    local mapRect = computeLayout(ctx)
    local view = computeView(ctx, mapRect)
    if not view then
      return true
    end

    -- Screen delta -> world delta via the current map scale.
    local wx = -(dx / view.scale)
    local wy = -(dy / view.scale)

    local sector = ctx and ctx.sector
    if sector then
      local zoom = mapUi.zoom or 1.0
      local viewW = sector.width / zoom
      local viewH = sector.height / zoom

      mapUi.centerX = (mapUi.centerX or (sector.width * 0.5)) + wx
      mapUi.centerY = (mapUi.centerY or (sector.height * 0.5)) + wy
      mapUi.centerX, mapUi.centerY = clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)
    end

    return true
  end

  function self.wheelmoved(ctx, x, y)
    if y == 0 then
      return false
    end

    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.open then
      return false
    end

    local before = mapUi.zoom or 1.0

    if y > 0 then
      mapUi.zoom = MathUtil.clamp(before * 1.12, 1.0, 20.0)
    else
      mapUi.zoom = MathUtil.clamp(before / 1.12, 1.0, 20.0)
    end

    local sector = ctx and ctx.sector
    if sector then
      local viewW = sector.width / (mapUi.zoom or 1.0)
      local viewH = sector.height / (mapUi.zoom or 1.0)
      mapUi.centerX, mapUi.centerY = clampCenter(sector, mapUi.centerX or (sector.width * 0.5), mapUi.centerY or (sector.height * 0.5), viewW, viewH)
    end

    return true
  end

  return self
end

return makeFullscreenMap()
