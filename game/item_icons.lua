local Items = require("game.items")

local ItemIcons = {}

local function resolveColor(id, opts)
  local def = Items.get(id)
  local base = (def and def.color) or { 1, 1, 1, 1 }

  local c = (opts and opts.color) or base
  local t = opts and opts.tint

  if not t then
    return c[1], c[2], c[3], c[4]
  end

  return c[1] * t[1], c[2] * t[2], c[3] * t[3], (c[4] or 1) * (t[4] or 1)
end

local function buildScaledPoints(cx, cy, size, points)
  local s = size * 0.5
  local out = {}
  for i = 1, #points, 2 do
    out[i] = cx + points[i] * s
    out[i + 1] = cy + points[i + 1] * s
  end
  return out
end

local function applyRelativeOffset(dst, src, dx, dy)
  for i = 1, #src, 2 do
    dst[i] = src[i] + dx
    dst[i + 1] = src[i + 1] + dy
  end
end

local function drawFromParams(id, cx, cy, size, opts)
  local def = Items.get(id)
  local icon = def and def.icon
  if not icon or type(icon) ~= "table" then
    return false
  end

  if icon.kind ~= "poly" or not icon.points then
    return false
  end

  local r, g, b, a = resolveColor(id, opts)
  local pts = buildScaledPoints(cx, cy, size, icon.points)

  local shadowDef = icon.shadow
  if shadowDef then
    local dx = (shadowDef.dx or 0) * size
    local dy = (shadowDef.dy or 0) * size
    local shadow = {}
    applyRelativeOffset(shadow, pts, dx, dy)
    love.graphics.setColor(0, 0, 0, (shadowDef.a or 0.0) * (a or 1))
    love.graphics.polygon("fill", shadow)
  end

  love.graphics.setColor(r, g, b, (icon.fillA or 1) * (a or 1))
  love.graphics.polygon("fill", pts)

  local outline = icon.outline
  if outline then
    if outline.width then
      love.graphics.setLineWidth(outline.width)
    end
    love.graphics.setColor(0, 0, 0, (outline.a or 1) * (a or 1))
    love.graphics.polygon("line", pts)
  end

  local highlight = icon.highlight
  if highlight and highlight.kind == "polyline" and highlight.points then
    if highlight.width then
      love.graphics.setLineWidth(highlight.width)
    end
    local hpts = buildScaledPoints(cx, cy, size, highlight.points)
    love.graphics.setColor(1, 1, 1, (highlight.a or 0.0) * (a or 1))
    love.graphics.line(hpts)
  end

  local detail = icon.detail
  if detail and detail.kind == "line" and detail.points then
    if detail.width then
      love.graphics.setLineWidth(detail.width)
    end
    local dpts = buildScaledPoints(cx, cy, size, detail.points)
    love.graphics.setColor(0, 0, 0, (detail.a or 0.0) * (a or 1))
    love.graphics.line(dpts)
  end

  return true
end

function ItemIcons.draw(id, x, y, w, h, opts)
  local size = math.min(w, h)
  local cx = x + w * 0.5
  local cy = y + h * 0.5

  love.graphics.push("all")
  drawFromParams(id, cx, cy, size, opts)
  love.graphics.pop()
end

function ItemIcons.drawCentered(id, cx, cy, size, opts)
  love.graphics.push("all")
  drawFromParams(id, cx, cy, size, opts)
  love.graphics.pop()
end

return ItemIcons
