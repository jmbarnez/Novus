local ControlsBottomLeft = {}

local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")

local pointInRect = Rect.pointInRect

local function getMapOpen(ctx)
  local world = ctx and ctx.world
  local mapUi = world and world.getResource and world:getResource("map_ui")
  return mapUi and mapUi.open
end

local function getLines()
  return {
    "W / Up: Thrust",
    "A / Left: Strafe left",
    "D / Right: Strafe right",
    "Space: Brake",
    "Mouse: Aim",
    "LMB: Fire",
    "RMB: Turret aim laser",
    "Ctrl+Click: Select/Clear target",
    "M: Map",
    "Wheel: Zoom",
  }
end

local function makeControlsBottomLeft()
  local self = {
    frame = WindowFrame.new(),
    bounds = nil,
  }

  local function recompute(ctx)
    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local controls = hudTheme.controls or {}

    local layout = ctx.layout or {}
    local margin = layout.margin or hudTheme.layout.margin

    local pad = controls.pad or 8
    local gap = controls.gap or 2

    local headerH = (hudTheme.cargoPanel and hudTheme.cargoPanel.headerH) or 24
    local footerH = (hudTheme.cargoPanel and hudTheme.cargoPanel.footerH) or 26

    local font = love.graphics.getFont()
    local lineH = font:getHeight()

    local title = "CONTROLS"
    local lines = getLines()

    local maxW = font:getWidth(title)
    for i = 1, #lines do
      local tw = font:getWidth(lines[i])
      if tw > maxW then
        maxW = tw
      end
    end

    local contentH = (#lines * lineH) + ((#lines - 1) * gap)
    local w = maxW + pad * 2
    local h = headerH + footerH + pad * 2 + contentH

    if self.frame.x == nil then
      self.frame.x = margin
    end
    if self.frame.y == nil then
      local screenH = ctx and ctx.screenH or 0
      self.frame.y = screenH - margin - h
    end

    self.bounds = self.frame:compute(ctx, w, h, {
      margin = margin,
      headerH = headerH,
      footerH = footerH,
      closeSize = 0,
      closePad = 0,
    })

    self.bounds.pad = pad
    self.bounds.gap = gap
    self.bounds.lineH = lineH
    self.bounds.lines = lines
  end

  function self.hitTest(ctx, x, y)
    if not ctx then
      return false
    end

    if getMapOpen(ctx) then
      return false
    end

    recompute(ctx)
    return self.bounds and pointInRect(x, y, self.bounds) or false
  end

  function self.draw(ctx)
    if not ctx then
      return
    end

    if getMapOpen(ctx) then
      return
    end

    recompute(ctx)
    local b = self.bounds
    if not b then
      return
    end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors
    local controls = hudTheme.controls or {}

    self.frame:draw(ctx, b, { title = "CONTROLS", titlePad = b.pad })

    local textAlpha = controls.textAlpha or 0.85

    local x = b.x + b.pad
    local y = b.y + (b.headerH or 0) + b.pad

    for i = 1, #b.lines do
      local t = b.lines[i]
      love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
      love.graphics.print(t, x + 1, y + 1)
      love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], textAlpha)
      love.graphics.print(t, x, y)
      y = y + b.lineH + b.gap
    end

    if ctx.layout then
      local stackGap = (hudTheme.layout and hudTheme.layout.stackGap) or 0
      ctx.layout.bottomLeftY = b.y - stackGap
    end

    love.graphics.setColor(1, 1, 1, 1)
  end

  function self.mousepressed(ctx, x, y, button)
    if not ctx or getMapOpen(ctx) then
      return false
    end

    recompute(ctx)
    local b = self.bounds
    if not b then
      return false
    end

    local consumed = self.frame:mousepressed(ctx, b, x, y, button)
    if consumed then
      return true
    end

    return false
  end

  function self.mousereleased(ctx, x, y, button)
    if not ctx or getMapOpen(ctx) then
      return false
    end
    return self.frame:mousereleased(ctx, x, y, button)
  end

  function self.mousemoved(ctx, x, y, dx, dy)
    if not ctx or getMapOpen(ctx) then
      return false
    end

    if self.frame:mousemoved(ctx, x, y, dx, dy) then
      recompute(ctx)
      return true
    end

    recompute(ctx)
    local b = self.bounds
    if b and pointInRect(x, y, b) then
      return true
    end

    return false
  end

  return self
end

return makeControlsBottomLeft()
