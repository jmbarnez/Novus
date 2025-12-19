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
  local colors = theme.hud.colors

  local w = 17
  local h = 4

  local margin = (theme.hud and theme.hud.layout and theme.hud.layout.margin) or 16
  local bottomOffset = 44

  -- Fill grows from 0 -> 1 as the cooldown counts down.
  local frac = MathUtil.clamp(1 - (timer / cooldown), 0, 1)

  local x = (ctx.screenW / 2) - (w / 2)
  local y = ctx.screenH - margin - bottomOffset

  love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4])
  love.graphics.rectangle("fill", x, y, w, h)

  love.graphics.setColor(colors.barFillPrimary[1], colors.barFillPrimary[2], colors.barFillPrimary[3], 0.98)
  love.graphics.rectangle("fill", x, y, w * frac, h)

  love.graphics.setColor(colors.barBorder[1], colors.barBorder[2], colors.barBorder[3], colors.barBorder[4])
  love.graphics.rectangle("line", x, y, w, h)

  love.graphics.setColor(1, 1, 1, 1)
end

return CursorCooldown
