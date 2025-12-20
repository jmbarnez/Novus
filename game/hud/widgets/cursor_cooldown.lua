local CursorCooldown = {}

local Theme = require("game.theme")
local MathUtil = require("util.math")

function CursorCooldown.draw(ctx)
  if not ctx then
    return
  end

  local cooldown = ctx.weaponCooldown
  local timer = ctx.weaponTimer
  if not cooldown or cooldown <= 0 or not timer or timer <= 0 then
    return
  end

  local theme = (ctx and ctx.theme) or Theme
  local hudTheme = theme.hud
  local colors = hudTheme.colors
  local cc = hudTheme.cursorCooldown or {}

  local w = cc.w or 17
  local h = cc.h or 4

  local margin = (hudTheme.layout and hudTheme.layout.margin) or 16
  local bottomOffset = cc.bottomOffset or 44
  local fillAlpha = cc.fillAlpha or 0.98

  -- Fill grows from 0 -> 1 as the cooldown counts down.
  local frac = MathUtil.clamp(1 - (timer / cooldown), 0, 1)

  local x = (ctx.screenW / 2) - (w / 2)
  local y = ctx.screenH - margin - bottomOffset

  love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4])
  love.graphics.rectangle("fill", x, y, w, h)

  love.graphics.setColor(colors.barFillPrimary[1], colors.barFillPrimary[2], colors.barFillPrimary[3], fillAlpha)
  love.graphics.rectangle("fill", x, y, w * frac, h)

  love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
  love.graphics.rectangle("line", x, y, w, h)

  love.graphics.setColor(1, 1, 1, 1)
end

return CursorCooldown
