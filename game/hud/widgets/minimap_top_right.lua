local MinimapTopRight = {}

local Theme = require("game.theme")
local MathUtil = require("util.math")
local Rect = require("util.rect")

local pointInRect = Rect.pointInRect

function MinimapTopRight.hitTest(ctx, x, y)
  if not ctx then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin

  local sector = ctx.sector
  if not sector or not sector.width or not sector.height or sector.width <= 0 or sector.height <= 0 then
    return false
  end

  local mapW, mapH = hudTheme.minimap.w, hudTheme.minimap.h
  local mapX = (ctx.screenW or 0) - margin - mapW
  local mapY = layout.topRightY or margin
  return pointInRect(x, y, { x = mapX, y = mapY, w = mapW, h = mapH })
end

function MinimapTopRight.draw(ctx)
  if not ctx then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local ps = hudTheme.panelStyle or {}

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin

  local sector = ctx.sector
  if not sector or not sector.width or not sector.height or sector.width <= 0 or sector.height <= 0 then
    return
  end

  local mapW, mapH = hudTheme.minimap.w, hudTheme.minimap.h
  local mapX = (ctx.screenW or 0) - margin - mapW
  local mapY = layout.topRightY or margin

  local cornerRadius = ps.radius or 0
  local inset = hudTheme.minimap.gridInset or 5

  -- outer glow/shadow
  local shadowOffset = ps.shadowOffset or 2
  local shadowAlpha = ps.shadowAlpha or 0.4
  if shadowOffset ~= 0 and shadowAlpha > 0 then
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", mapX + shadowOffset, mapY + shadowOffset, mapW, mapH, cornerRadius, cornerRadius)
  end

  -- main background with gradient effect (darker at edges)
  love.graphics.setColor(colors.minimapBg[1] * 0.7, colors.minimapBg[2] * 0.7, colors.minimapBg[3] * 0.7,
    colors.minimapBg[4])
  love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, cornerRadius, cornerRadius)

  -- inner lighter area
  love.graphics.setColor(colors.minimapBg[1], colors.minimapBg[2], colors.minimapBg[3], colors.minimapBg[4] * 0.8)
  local innerR = cornerRadius > 1 and (cornerRadius - 1) or 0
  love.graphics.rectangle("fill", mapX + inset, mapY + inset, mapW - inset * 2, mapH - inset * 2, innerR, innerR)

  -- asteroids
  local world = ctx.world
  if world and world.query then
    local maxAsteroids = 250
    local drawn = 0

    local asteroidSize = 2
    local asteroidHalf = asteroidSize / 2

    world:query({ "asteroid", "physics_body" }, function(e)
      if drawn >= maxAsteroids then
        return
      end

      local body = e.physics_body and e.physics_body.body
      if not body then
        return
      end

      local ax, ay = body:getPosition()
      local mx = mapX + (ax / sector.width) * mapW
      local my = mapY + (ay / sector.height) * mapH

      if mx < mapX + inset or mx > mapX + mapW - inset or my < mapY + inset or my > mapY + mapH - inset then
        return
      end

      love.graphics.setColor(colors.minimapGrid[1], colors.minimapGrid[2], colors.minimapGrid[3], 0.35)
      love.graphics.rectangle("fill", mx - asteroidHalf, my - asteroidHalf, asteroidSize, asteroidSize)
      drawn = drawn + 1
    end)
  end

  -- player indicator
  if ctx.hasShip then
    local px = mapX + ((ctx.x or 0) / sector.width) * mapW
    local py = mapY + ((ctx.y or 0) / sector.height) * mapH

    px = MathUtil.clamp(px, mapX + inset, mapX + mapW - inset)
    py = MathUtil.clamp(py, mapY + inset, mapY + mapH - inset)

    local dotRadius = hudTheme.minimap.playerDotRadius

    -- outer glow
    love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.3)
    love.graphics.circle("fill", px, py, dotRadius * 2.5)

    -- middle ring
    love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3], 0.6)
    love.graphics.circle("fill", px, py, dotRadius * 1.5)

    -- bright center
    love.graphics.setColor(colors.minimapPlayer[1], colors.minimapPlayer[2], colors.minimapPlayer[3],
      colors.minimapPlayer[4])
    love.graphics.circle("fill", px, py, dotRadius)

    -- white core
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", px, py, dotRadius * 0.4)
  end

  local mapUi = world and world.getResource and world:getResource("map_ui")
  if mapUi and mapUi.waypointX and mapUi.waypointY then
    local wx = mapX + (mapUi.waypointX / sector.width) * mapW
    local wy = mapY + (mapUi.waypointY / sector.height) * mapH

    wx = MathUtil.clamp(wx, mapX + inset, mapX + mapW - inset)
    wy = MathUtil.clamp(wy, mapY + inset, mapY + mapH - inset)

    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], colors.accent[4])
    love.graphics.setLineWidth(2)
    love.graphics.line(wx - 5, wy, wx + 5, wy)
    love.graphics.line(wx, wy - 5, wx, wy + 5)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3], colors.panelBorder[4])
  love.graphics.setLineWidth(ps.borderWidth or 1)
  love.graphics.rectangle("line", mapX, mapY, mapW, mapH, cornerRadius, cornerRadius)
  love.graphics.setLineWidth(1)

  if ctx.layout then
    ctx.layout.topRightY = mapY + mapH + hudTheme.layout.stackGap
  end

  love.graphics.setColor(1, 1, 1, 1)
end

function MinimapTopRight.mousepressed(ctx, x, y, button)
  if not ctx or not ctx.world then
    return false
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud

  local layout = ctx.layout or {}
  local margin = layout.margin or hudTheme.layout.margin

  local sector = ctx.sector
  if not sector or not sector.width or not sector.height or sector.width <= 0 or sector.height <= 0 then
    return false
  end

  local mapW, mapH = hudTheme.minimap.w, hudTheme.minimap.h
  local mapX = (ctx.screenW or 0) - margin - mapW
  local mapY = (layout.topRightY or margin)

  if not pointInRect(x, y, { x = mapX, y = mapY, w = mapW, h = mapH }) then
    return false
  end

  if button ~= 1 then
    return true
  end

  local mapUi = ctx.world:getResource("map_ui")
  if mapUi then
    mapUi.open = true
    mapUi.zoom = mapUi.zoom or 1.0
    if ctx.hasShip then
      mapUi.centerX = ctx.x
      mapUi.centerY = ctx.y
    end
  end

  local uiCapture = ctx.world:getResource("ui_capture")
  if uiCapture then
    uiCapture.active = true
  end

  return true
end

return MinimapTopRight
