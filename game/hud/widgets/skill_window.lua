local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")

local pointInRect = Rect.pointInRect

local function makeSkillWindow()
  local self = {
    windowFrame = WindowFrame.new(),
    open = false,
  }

  local WINDOW_W = 460
  local WINDOW_H = 260
  local HEADER_H = 32
  local CONTENT_PAD = 14

  local function computeLayout(ctx)
    local bounds = self.windowFrame:compute(ctx, WINDOW_W, WINDOW_H, {
      headerH = HEADER_H,
      closeSize = 16,
      closePad = 8,
    })

    bounds.content = {
      x = bounds.x + CONTENT_PAD,
      y = bounds.y + HEADER_H + CONTENT_PAD,
      w = WINDOW_W - CONTENT_PAD * 2,
      h = WINDOW_H - HEADER_H - CONTENT_PAD * 2,
    }

    return bounds
  end

  local function getSkillProgress(ctx, key)
    local level = 1
    local xp = 0
    local xpToNext = 100

    local player = ctx and ctx.world and ctx.world:getResource("player")
    if player and player:has("player_progress") then
      local pp = player.player_progress
      local skills = pp.skills
      local skill = skills and skills[key]

      level = (skill and skill.level) or level
      xp = (skill and skill.xp) or xp
      xpToNext = (skill and skill.xpToNext) or xpToNext
    end

    return level, xp, xpToNext
  end

  local function drawMiningIcon(x, y, size)
    local shaftLen = size * 0.65
    local headW = size * 0.45
    local headH = size * 0.28

    local baseX = x + size * 0.2
    local baseY = y + size * 0.75
    local tipX = baseX + shaftLen
    local tipY = baseY - shaftLen * 0.45

    love.graphics.setLineWidth(3)
    love.graphics.setColor(0.20, 0.85, 1.00, 0.95)
    love.graphics.line(baseX, baseY, tipX, tipY)

    love.graphics.setLineWidth(4)
    love.graphics.setColor(0.90, 0.98, 1.00, 0.95)
    love.graphics.line(
      tipX - headW * 0.5,
      tipY - headH,
      tipX + headW * 0.5,
      tipY
    )
    love.graphics.line(
      tipX - headW * 0.5,
      tipY + headH,
      tipX + headW * 0.5,
      tipY
    )

    love.graphics.setLineWidth(1)
  end

  local function drawMiningCard(ctx, bounds)
    local theme = (ctx and ctx.theme) or Theme
    local colors = theme.hud.colors
    local font = love.graphics.getFont()

    local pad = 12
    local cardH = bounds.h - pad * 2
    local cardRect = { x = bounds.x, y = bounds.y, w = bounds.w, h = cardH }

    love.graphics.setColor(0.08, 0.12, 0.18, 0.92)
    love.graphics.rectangle("fill", cardRect.x, cardRect.y, cardRect.w, cardRect.h, 6)

    love.graphics.setColor(0.30, 0.45, 0.65, 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", cardRect.x, cardRect.y, cardRect.w, cardRect.h, 6)
    love.graphics.setLineWidth(1)

    local iconSize = 64
    local iconX = cardRect.x + pad
    local iconY = cardRect.y + pad
    drawMiningIcon(iconX, iconY, iconSize)

    local level, xp, xpToNext = getSkillProgress(ctx, "mining")
    local title = "Mining"
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.95)
    love.graphics.print(title, iconX + iconSize + 12, iconY + 4)

    local levelText = string.format("Level %d", level)
    love.graphics.setColor(0.60, 0.90, 1.00, 0.9)
    love.graphics.print(levelText, iconX + iconSize + 12, iconY + 26)

    local barW = cardRect.w - pad * 2
    local barH = 18
    local barX = cardRect.x + pad
    local barY = cardRect.y + cardRect.h - pad - barH

    local progress = (xpToNext > 0) and math.min(1, xp / xpToNext) or 0
    love.graphics.setColor(0.10, 0.16, 0.24, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4)

    local fill = math.floor(barW * progress)
    love.graphics.setColor(0.20, 0.85, 1.00, 0.95)
    love.graphics.rectangle("fill", barX, barY, fill, barH, 4)

    love.graphics.setColor(0.30, 0.45, 0.65, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, barH, 4)

    local xpText = string.format("%d / %d xp", xp, xpToNext)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(xpText, barX + 8, barY - font:getHeight() - 2)
  end

  local function drawMetallurgyIcon(x, y, size)
    local baseW = size * 0.9
    local baseH = size * 0.28
    local topW = size * 0.65
    local topH = size * 0.14
    local inset = (baseW - topW) / 2

    love.graphics.setColor(0.85, 0.65, 0.25, 0.95)
    love.graphics.rectangle("fill", x, y + size - baseH, baseW, baseH, 4)
    love.graphics.setColor(0.95, 0.85, 0.55, 0.9)
    love.graphics.rectangle("fill", x + inset, y + size - baseH - topH, topW, topH, 3)
    love.graphics.setColor(0.25, 0.22, 0.18, 0.9)
    love.graphics.rectangle("fill", x + baseW * 0.35, y + size - baseH - topH - topH * 0.6, baseW * 0.3, topH * 0.6, 3)
  end

  local function drawMetallurgyCard(ctx, bounds)
    local theme = (ctx and ctx.theme) or Theme
    local colors = theme.hud.colors
    local font = love.graphics.getFont()

    local pad = 12
    local cardH = bounds.h - pad * 2
    local cardRect = { x = bounds.x, y = bounds.y, w = bounds.w, h = cardH }

    love.graphics.setColor(0.10, 0.10, 0.12, 0.92)
    love.graphics.rectangle("fill", cardRect.x, cardRect.y, cardRect.w, cardRect.h, 6)

    love.graphics.setColor(0.70, 0.55, 0.30, 0.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", cardRect.x, cardRect.y, cardRect.w, cardRect.h, 6)
    love.graphics.setLineWidth(1)

    local iconSize = 64
    local iconX = cardRect.x + pad
    local iconY = cardRect.y + pad
    drawMetallurgyIcon(iconX, iconY, iconSize)

    local level, xp, xpToNext = getSkillProgress(ctx, "metallurgy")
    local title = "Metallurgy"
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.95)
    love.graphics.print(title, iconX + iconSize + 12, iconY + 4)

    local levelText = string.format("Level %d", level)
    love.graphics.setColor(0.95, 0.80, 0.45, 0.9)
    love.graphics.print(levelText, iconX + iconSize + 12, iconY + 26)

    local barW = cardRect.w - pad * 2
    local barH = 18
    local barX = cardRect.x + pad
    local barY = cardRect.y + cardRect.h - pad - barH

    local progress = (xpToNext > 0) and math.min(1, xp / xpToNext) or 0
    love.graphics.setColor(0.14, 0.12, 0.10, 0.9)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4)

    local fill = math.floor(barW * progress)
    love.graphics.setColor(0.95, 0.70, 0.30, 0.95)
    love.graphics.rectangle("fill", barX, barY, fill, barH, 4)

    love.graphics.setColor(0.70, 0.55, 0.30, 0.85)
    love.graphics.rectangle("line", barX, barY, barW, barH, 4)

    local xpText = string.format("%d / %d xp", xp, xpToNext)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(xpText, barX + 8, barY - font:getHeight() - 2)
  end

  function self.hitTest(ctx, x, y)
    if not self.open then
      return false
    end

    local bounds = computeLayout(ctx)
    return pointInRect(x, y, bounds)
  end

  function self.draw(ctx)
    if not self.open then
      return
    end

    local bounds = computeLayout(ctx)
    self.windowFrame:draw(ctx, bounds, {
      title = "SKILLS",
      headerAlpha = 0.5,
      headerLineAlpha = 0.4,
      owner = self,
    })

    local gap = 12
    local cardW = (bounds.content.w - gap) / 2
    local cardH = bounds.content.h

    drawMiningCard(ctx, { x = bounds.content.x, y = bounds.content.y, w = cardW, h = cardH })
    drawMetallurgyCard(ctx, { x = bounds.content.x + cardW + gap, y = bounds.content.y, w = cardW, h = cardH })
  end

  function self.keypressed(ctx, key)
    if key == "k" then
      self.open = not self.open
      if self.open and ctx and ctx.hud then
        ctx.hud:bringToFront(self)
      end
      return true
    end

    if not self.open then
      return false
    end

    if key == "escape" then
      self.open = false
      return true
    end

    return false
  end

  function self.mousepressed(ctx, x, y, button)
    if not self.open then
      return false
    end

    local bounds = computeLayout(ctx)

    if pointInRect(x, y, bounds) and ctx and ctx.hud then
      ctx.hud:bringToFront(self)
    end

    local consumed, closeHit, headerDrag = self.windowFrame:mousepressed(ctx, bounds, x, y, button)
    if closeHit then
      self.open = false
      return true
    end
    if consumed or headerDrag then
      return true
    end

    return pointInRect(x, y, bounds)
  end

  function self.mousereleased(ctx, x, y, button)
    if not self.open then
      return false
    end

    return self.windowFrame:mousereleased(ctx, x, y, button)
  end

  function self.mousemoved(ctx, x, y, dx, dy)
    if not self.open then
      return false
    end

    return self.windowFrame:mousemoved(ctx, x, y, dx, dy)
  end

  function self.wheelmoved(ctx, x, y)
    if not self.open then
      return false
    end

    return false
  end

  return self
end

return makeSkillWindow()
