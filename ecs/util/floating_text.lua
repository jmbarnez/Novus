local Theme = require("game.theme")

local M = {}

local function copyColor(c)
  if not c then
    return nil
  end
  return { c[1], c[2], c[3], c[4] }
end

local function buildStackText(amount, opts)
  local prefix = opts and opts.prefix or "+"
  local label = opts and opts.stackLabel
  local suffix = opts and opts.amountSuffix
  local amountText = tostring(amount)
  if suffix and suffix ~= "" then
    amountText = amountText .. tostring(suffix)
  end
  if label ~= nil and label ~= "" then
    return prefix .. amountText .. " " .. tostring(label)
  end
  return prefix .. amountText
end

function M.spawn(world, x, y, text, opts)
  if not world or not world.newEntity then
    return nil
  end

  opts = opts or {}

  local themeColors = Theme and Theme.hud and Theme.hud.colors
  local kind = opts.kind

  local color = opts.color
  if color == nil and themeColors and kind then
    if kind == "damage" then
      color = { themeColors.danger[1], themeColors.danger[2], themeColors.danger[3], 0.95 }
    elseif kind == "pickup" then
      color = copyColor(themeColors.pickup)
    elseif kind == "xp" then
      color = { themeColors.warn[1], themeColors.warn[2], themeColors.warn[3], 0.95 }
    end
  end

  local e = world:newEntity()
    :give("floating_text", text, x, y, {
      vx = opts.vx,
      vy = opts.vy,
      riseSpeed = opts.riseSpeed,
      ax = opts.ax,
      ay = opts.ay,
      duration = opts.duration,
      fadeOutFrac = opts.fadeOutFrac,
      scale = opts.scale,
      color = color,
      shadow = opts.shadow,
      shadowOffsetX = opts.shadowOffsetX,
      shadowOffsetY = opts.shadowOffsetY,
    })

  return e
end

function M.spawnStacked(world, x, y, stackKey, addAmount, opts)
  if not world or not world.query then
    return nil
  end

  opts = opts or {}

  local stackRadius = opts.stackRadius or 80
  local stackWindow = opts.stackWindow or 0.4
  local best = nil
  local bestDist2 = nil

  world:query({ "floating_text" }, function(e)
    local c = e and e.floating_text
    if not c then
      return
    end

    if c.stackKey ~= stackKey then
      return
    end

    if c.duration and c.t and stackWindow > 0 then
      local age = c.duration - c.t
      if age > stackWindow then
        return
      end
    end

    local dx = (c.x or 0) - x
    local dy = (c.y or 0) - y
    local dist2 = dx * dx + dy * dy
    if dist2 > (stackRadius * stackRadius) then
      return
    end

    if bestDist2 == nil or dist2 < bestDist2 then
      best = e
      bestDist2 = dist2
    end
  end)

  if best and best.floating_text then
    local c = best.floating_text
    c.stackAmount = (c.stackAmount or 0) + (addAmount or 0)
    c.text = buildStackText(c.stackAmount, opts)
    c.duration = opts.duration or c.duration
    c.t = c.duration
    if opts.riseSpeed ~= nil then
      c.vy = -math.abs(opts.riseSpeed)
    end
    if opts.scale ~= nil then
      c.scale = opts.scale
    end
    if opts.color ~= nil then
      c.color = opts.color
    end
    return best
  end

  local e = M.spawn(world, x, y, buildStackText(addAmount or 0, opts), opts)
  if e and e.floating_text then
    e.floating_text.stackKey = stackKey
    e.floating_text.stackAmount = addAmount or 0
  end
  return e
end

return M
