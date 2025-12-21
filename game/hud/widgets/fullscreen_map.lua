--- Fullscreen Map HUD Widget
--- Uses fullscreen_map_view and fullscreen_map_draw for view calculations and drawing

local Theme = require("game.theme")
local MathUtil = require("util.math")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local MapView = require("game.hud.widgets.fullscreen_map_view")
local MapDraw = require("game.hud.widgets.fullscreen_map_draw")

local pointInRect = Rect.pointInRect

local function makeFullscreenMap()
  local self = {
    dragging = false,
    dragStart = nil,
    dragStartCenter = nil,
    dragMoved = false,
    windowFrame = WindowFrame.new(),
  }

  -- State access ---------------------------------------------------------
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

  -- Layout helper --------------------------------------------------------
  local function computeLayoutAndView(ctx)
    local mapUi = getMapUi(ctx)
    local mapRect, legendRect, windowRect, frameBounds = MapView.computeLayout(ctx, self.windowFrame)
    local view = MapView.computeView(ctx, mapRect, mapUi)

    return {
      mapRect = mapRect,
      legendRect = legendRect,
      windowRect = windowRect,
      frameBounds = frameBounds,
      view = view,
    }
  end

  -- Interface: draw ------------------------------------------------------
  function self.hitTest(ctx, x, y)
    local mapUi = getMapUi(ctx)
    return mapUi and mapUi.open or false
  end

  function self.draw(ctx)
    local mapUi = getMapUi(ctx)
    if not ctx or not mapUi or not mapUi.open then
      return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud

    local layout = computeLayoutAndView(ctx)
    if not layout.view then
      return
    end

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, ctx.screenW or 0, ctx.screenH or 0)

    if layout.frameBounds then
      self.windowFrame:draw(ctx, layout.frameBounds, {
        title = (hudTheme.fullscreenMap and hudTheme.fullscreenMap.title) or "MAP",
        headerAlpha = 0.55,
        headerLineAlpha = 0.4,
      })
    end

    MapDraw.drawMapContent(ctx, layout.view)
    MapDraw.drawLegend(ctx, layout.legendRect)

    local font = love.graphics.getFont()
    local header = string.format("ZOOM %.1fx", layout.view.zoom)

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(header, layout.mapRect.x + 1, layout.mapRect.y - font:getHeight() - 2 + 1)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(header, layout.mapRect.x, layout.mapRect.y - font:getHeight() - 2)

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

    mapUi.centerX, mapUi.centerY = MapView.clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)

    return true
  end

  function self.mousepressed(ctx, x, y, button)
    local mapUi = getMapUi(ctx)
    if not mapUi or not mapUi.open then
      return false
    end

    local layout = computeLayoutAndView(ctx)
    local consumed, closeHit, headerDrag = self.windowFrame:mousepressed(ctx, layout.frameBounds, x, y, button)
    if closeHit then
      setOpen(ctx, false)
      return true
    end
    if headerDrag then
      return true
    end

    local view = layout.view
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

    if layout.legendRect and pointInRect(x, y, layout.legendRect) then
      local btn = MapView.legendButtonRect(layout.legendRect)
      if btn and pointInRect(x, y, btn) and ctx.hasShip then
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

    if self.windowFrame:mousereleased(ctx, x, y, button) then
      return true
    end

    if button == 1 and self.dragging then
      local layout = computeLayoutAndView(ctx)
      local view = layout.view
      if view and (not self.dragMoved) and pointInRect(x, y, view.drawRect) then
        local wx, wy = MapView.screenToWorld(view, x, y)
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
    if not mapUi or not mapUi.open then
      return false
    end

    if self.windowFrame:mousemoved(ctx, x, y, dx, dy) then
      return true
    end

    if not self.dragging then
      return false
    end

    if math.abs(dx) + math.abs(dy) > 2 then
      self.dragMoved = true
    end

    local layout = computeLayoutAndView(ctx)
    local view = layout.view
    if not view then
      return true
    end

    local wx = -(dx / view.scale)
    local wy = -(dy / view.scale)

    local sector = ctx and ctx.sector
    if sector then
      local zoom = mapUi.zoom or 1.0
      local viewW = sector.width / zoom
      local viewH = sector.height / zoom

      mapUi.centerX = (mapUi.centerX or (sector.width * 0.5)) + wx
      mapUi.centerY = (mapUi.centerY or (sector.height * 0.5)) + wy
      mapUi.centerX, mapUi.centerY = MapView.clampCenter(sector, mapUi.centerX, mapUi.centerY, viewW, viewH)
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
      mapUi.centerX, mapUi.centerY = MapView.clampCenter(sector, mapUi.centerX or (sector.width * 0.5),
        mapUi.centerY or (sector.height * 0.5), viewW, viewH)
    end

    return true
  end

  return self
end

return makeFullscreenMap()
