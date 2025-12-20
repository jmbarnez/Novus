local ControlsBottomLeft = {}

local Theme = require("game.theme")

local function getMapOpen(ctx)
  local world = ctx and ctx.world
  local mapUi = world and world.getResource and world:getResource("map_ui")
  return mapUi and mapUi.open
end

function ControlsBottomLeft.hitTest(ctx, x, y)
  if not ctx then
    return false
  end

  if getMapOpen(ctx) then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local controls = hudTheme.controls or {}

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local x0 = margin
  local yBottom = layout.bottomLeftY or ((ctx.screenH or 0) - margin)

  local pad = controls.pad or 8
  local gap = controls.gap or 2

  local lines = {
    { kind = "title", text = "CONTROLS" },
    { text = "W / Up: Thrust" },
    { text = "A / Left: Strafe left" },
    { text = "D / Right: Strafe right" },
    { text = "Space: Brake" },
    { text = "Mouse: Aim" },
    { text = "LMB: Fire" },
    { text = "RMB: Turret aim laser" },
    { text = "Ctrl+Click: Select/Clear target" },
    { text = "M: Map" },
    { text = "Wheel: Zoom" },
  }

  local font = love.graphics.getFont()
  local lineH = font:getHeight()

  local maxW = 0
  for i = 1, #lines do
    local tw = font:getWidth(lines[i].text)
    if tw > maxW then
      maxW = tw
    end
  end

  local w = maxW + pad * 2
  local h = pad * 2 + (#lines * lineH) + ((#lines - 1) * gap)
  local y0 = yBottom - h

  return x >= x0 and x <= (x0 + w) and y >= y0 and y <= (y0 + h)
end

function ControlsBottomLeft.draw(ctx)
  if not ctx then
    return
  end

  if getMapOpen(ctx) then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local controls = hudTheme.controls or {}
  local ps = hudTheme.panelStyle or {}

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local x0 = margin
  local yBottom = layout.bottomLeftY or ((ctx.screenH or 0) - margin)

  local pad = controls.pad or 8
  local gap = controls.gap or 2
  local textAlpha = controls.textAlpha or 0.85

  local lines = {
    { kind = "title", text = "CONTROLS" },
    { text = "W / Up: Thrust" },
    { text = "A / Left: Strafe left" },
    { text = "D / Right: Strafe right" },
    { text = "Space: Brake" },
    { text = "Mouse: Aim" },
    { text = "LMB: Fire" },
    { text = "RMB: Turret aim laser" },
    { text = "Ctrl+Click: Select/Clear target" },
    { text = "M: Map" },
    { text = "Wheel: Zoom" },
  }

  local font = love.graphics.getFont()
  local lineH = font:getHeight()

  local maxW = 0
  for i = 1, #lines do
    local tw = font:getWidth(lines[i].text)
    if tw > maxW then
      maxW = tw
    end
  end

  local w = maxW + pad * 2
  local h = pad * 2 + (#lines * lineH) + ((#lines - 1) * gap)

  local y0 = yBottom - h

  local r = ps.radius or 0
  local shadowOffset = ps.shadowOffset or 0
  local shadowAlpha = ps.shadowAlpha or 0
  if shadowOffset ~= 0 and shadowAlpha > 0 then
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", x0 + shadowOffset, y0 + shadowOffset, w, h, r, r)
  end

  love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4])
  love.graphics.rectangle("fill", x0, y0, w, h, r, r)

  love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], colors.panelBorder[4])
  love.graphics.setLineWidth(ps.borderWidth or 1)
  love.graphics.rectangle("line", x0, y0, w, h, r, r)
  love.graphics.setLineWidth(1)

  local x = x0 + pad
  local y = y0 + pad

  for i = 1, #lines do
    local line = lines[i]

    if line.kind == "title" then
      love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
      love.graphics.print(line.text, x + 1, y + 1)
      love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4])
      love.graphics.print(line.text, x, y)
    else
      love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], colors.textShadow[4])
      love.graphics.print(line.text, x + 1, y + 1)
      love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], textAlpha)
      love.graphics.print(line.text, x, y)
    end

    y = y + lineH + gap
  end

  if ctx.layout then
    local stackGap = (hudTheme.layout and hudTheme.layout.stackGap) or 0
    ctx.layout.bottomLeftY = y0 - stackGap
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return ControlsBottomLeft
