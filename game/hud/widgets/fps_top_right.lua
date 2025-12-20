local FpsTopRight = {}

local Theme = require("game.theme")

function FpsTopRight.hitTest(ctx, x, y)
  if not ctx then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local xRight = (ctx.screenW or 0) - margin
  local y0 = layout.topRightY or margin

  local text = tostring(ctx.fps or 0)
  local font = love.graphics.getFont()
  local tw = font:getWidth(text)
  local th = font:getHeight()

  local coordText = string.format("X %d  Y %d", math.floor(ctx.x or 0), math.floor(ctx.y or 0))
  local tw2 = font:getWidth(coordText)

  local x1 = xRight - tw
  local x2 = xRight - tw2
  local left = math.min(x1, x2)
  local right = xRight
  local bottom = y0 + th * 2 + (hudTheme.layout and hudTheme.layout.smallGap or 0)

  return x >= left and x <= right and y >= y0 and y <= bottom
end

function FpsTopRight.draw(ctx)
  if not ctx then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin
  local xRight = (ctx.screenW or 0) - margin
  local y = layout.topRightY or margin

  local text = tostring(ctx.fps or 0)
  local font = love.graphics.getFont()
  local tw = font:getWidth(text)

  local x = xRight - tw

  love.graphics.setColor(colors.fpsText[1], colors.fpsText[2], colors.fpsText[3], colors.fpsText[4])
  love.graphics.print(text, x, y)

  -- subtle bracket accents
  local bracketOffsetX = hudTheme.fps.bracketOffsetX
  local bracketInsetY = hudTheme.fps.bracketInsetY
  love.graphics.setColor(colors.fpsBrackets[1], colors.fpsBrackets[2], colors.fpsBrackets[3], colors.fpsBrackets[4])
  love.graphics.line(x - bracketOffsetX, y + bracketInsetY, x - bracketOffsetX, y + font:getHeight() - bracketInsetY)
  love.graphics.line(x + tw + bracketOffsetX, y + bracketInsetY, x + tw + bracketOffsetX, y + font:getHeight() - bracketInsetY)

  local coordText = string.format("X %d  Y %d", math.floor(ctx.x or 0), math.floor(ctx.y or 0))
  local y2 = y + font:getHeight() + hudTheme.layout.smallGap
  local tw2 = font:getWidth(coordText)
  local x2 = xRight - tw2
  love.graphics.setColor(colors.fpsText[1], colors.fpsText[2], colors.fpsText[3], 0.75)
  love.graphics.print(coordText, x2, y2)
  love.graphics.setColor(1, 1, 1, 1)

  if ctx.layout then
    ctx.layout.topRightY = y2 + font:getHeight() + hudTheme.layout.smallGap
  end
end

return FpsTopRight
