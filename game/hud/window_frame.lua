local Theme = require("game.theme")
local Rect = require("util.rect")

local pointInRect = Rect.pointInRect

local WindowFrame = {}
WindowFrame.__index = WindowFrame

function WindowFrame.new()
  local self = setmetatable({}, WindowFrame)
  self.x = nil
  self.y = nil
  self.dragging = false
  self.dragOffsetX = 0
  self.dragOffsetY = 0
  return self
end

function WindowFrame:compute(ctx, w, h, opts)
  opts = opts or {}

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud

  local screenW = ctx and ctx.screenW or 0
  local screenH = ctx and ctx.screenH or 0

  local margin = opts.margin
  if margin == nil then
    margin = (ctx and ctx.layout and ctx.layout.margin) or (hudTheme.layout and hudTheme.layout.margin) or 16
  end

  local headerH = opts.headerH or 0
  local footerH = opts.footerH or 0

  local x0 = self.x
  local y0 = self.y
  if x0 == nil or y0 == nil then
    x0 = math.floor((screenW - w) / 2)
    y0 = math.floor((screenH - h) / 2)
  end

  if screenW > 0 then
    local minX = margin
    local maxX = screenW - margin - w
    if x0 < minX then
      x0 = minX
    elseif x0 > maxX then
      x0 = maxX
    end
  end

  if screenH > 0 then
    local minY = margin
    local maxY = screenH - margin - h
    if y0 < minY then
      y0 = minY
    elseif y0 > maxY then
      y0 = maxY
    end
  end

  self.x = x0
  self.y = y0

  local bounds = {
    x = x0,
    y = y0,
    w = w,
    h = h,
    headerH = headerH,
    footerH = footerH,
  }

  if headerH > 0 then
    bounds.headerRect = { x = x0, y = y0, w = w, h = headerH }
  end

  if footerH > 0 then
    bounds.footerRect = { x = x0, y = y0 + h - footerH, w = w, h = footerH }
  end

  local closeSize = opts.closeSize or 0
  local closePad = opts.closePad or 0
  if closeSize > 0 and headerH > 0 then
    bounds.closeRect = {
      x = x0 + w - closePad - closeSize,
      y = y0 + math.floor((headerH - closeSize) * 0.5),
      w = closeSize,
      h = closeSize,
    }
  end

  return bounds
end

function WindowFrame:draw(ctx, bounds, opts)
  if not ctx or not bounds then
    return
  end

  opts = opts or {}

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local ps = hudTheme.panelStyle or {}

  local r = ps.radius or 0

  love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4])
  love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.w, bounds.h, r, r)

  love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], colors.panelBorder[4])
  love.graphics.setLineWidth(ps.borderWidth or 1)
  love.graphics.rectangle("line", bounds.x, bounds.y, bounds.w, bounds.h, r, r)
  love.graphics.setLineWidth(1)

  local header = bounds.headerRect
  if header then
    love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], opts.headerAlpha or 0.45)
    love.graphics.rectangle("fill", header.x, header.y, header.w, header.h, r, r)

    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
      opts.headerLineAlpha or 0.35)
    love.graphics.line(header.x, header.y + header.h, header.x + header.w, header.y + header.h)

    local title = opts.title
    if title then
      local pad = opts.titlePad
      if pad == nil then
        pad = 6
      end
      local font = love.graphics.getFont()
      local th = font:getHeight()
      local ty = header.y + math.floor((header.h - th) * 0.5)

      love.graphics.setColor(colors.textShadow[1], colors.textShadow[2], colors.textShadow[3], 0.75)
      love.graphics.print(title, header.x + pad + 1, ty + 1)
      love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.9)
      love.graphics.print(title, header.x + pad, ty)
    end

    local close = bounds.closeRect
    if close then
      local mx, my = love.mouse.getPosition()
      local hoverClose = (ctx and ctx.hoverWidget == opts.owner) and pointInRect(mx, my, close)

      love.graphics.setColor(0, 0, 0, hoverClose and 0.55 or 0.35)
      love.graphics.rectangle("fill", close.x, close.y, close.w, close.h, r, r)
      love.graphics.setColor(1, 1, 1, hoverClose and 0.45 or 0.25)
      love.graphics.rectangle("line", close.x, close.y, close.w, close.h, r, r)
      love.graphics.setColor(1, 1, 1, hoverClose and 0.9 or 0.7)
      love.graphics.line(close.x + 4, close.y + 4, close.x + close.w - 4, close.y + close.h - 4)
      love.graphics.line(close.x + close.w - 4, close.y + 4, close.x + 4, close.y + close.h - 4)
    end
  end

  local footer = bounds.footerRect
  if footer then
    love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], opts.footerAlpha or 0.45)
    love.graphics.rectangle("fill", footer.x, footer.y, footer.w, footer.h, r, r)
    love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
      opts.footerLineAlpha or 0.35)
    love.graphics.line(footer.x, footer.y, footer.x + footer.w, footer.y)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function WindowFrame:mousepressed(ctx, bounds, x, y, button)
  if not bounds or not pointInRect(x, y, bounds) then
    return false, false, false
  end

  if button ~= 1 then
    return true, false, false
  end

  if bounds.closeRect and pointInRect(x, y, bounds.closeRect) then
    return true, true, false
  end

  if bounds.headerRect and pointInRect(x, y, bounds.headerRect) then
    self.dragging = true
    self.dragOffsetX = x - bounds.x
    self.dragOffsetY = y - bounds.y
    return true, false, true
  end

  return false, false, false
end

function WindowFrame:mousereleased(ctx, x, y, button)
  if button == 1 and self.dragging then
    self.dragging = false
    return true
  end
  return false
end

function WindowFrame:mousemoved(ctx, x, y, dx, dy)
  if not self.dragging then
    return false
  end

  self.x = x - (self.dragOffsetX or 0)
  self.y = y - (self.dragOffsetY or 0)
  return true
end

return WindowFrame
