local Utils = {}

function Utils.lerp(a, b, t)
  return a + (b - a) * t
end

function Utils.lerpAngle(a, b, t)
  local d = (b - a + math.pi) % (math.pi * 2) - math.pi
  return a + d * t
end

function Utils.applyFlashToColor(e, r, g, b, a)
  if e:has("hit_flash") then
    local t = e.hit_flash.t / e.hit_flash.duration
    r = r + (1 - r) * t
    g = g + (1 - g) * t
    b = b + (1 - b) * t
  end

  return r, g, b, a
end

function Utils.applyFlashColor(e)
  local r, g, b, a = e.renderable.color[1], e.renderable.color[2], e.renderable.color[3], e.renderable.color[4]

  if e:has("hit_flash") then
    local t = e.hit_flash.t / e.hit_flash.duration
    r = r + (1 - r) * t
    g = g + (1 - g) * t
    b = b + (1 - b) * t
  end

  love.graphics.setColor(r, g, b, a)
end

local function buildExpandedOutlineCoords(baseCoords, pad)
  local coords = {}
  for i = 1, #baseCoords, 2 do
    local x = baseCoords[i]
    local y = baseCoords[i + 1]
    local len = math.sqrt(x * x + y * y)
    if len > 0.0001 then
      local s = (len + pad) / len
      coords[i] = x * s
      coords[i + 1] = y * s
    else
      coords[i] = x
      coords[i + 1] = y
    end
  end
  return coords
end

function Utils.getAsteroidTargetOutlineCoords(e, shape, pad)
  local a = e.asteroid
  if not a then
    return nil
  end

  local baseCoords
  if a.renderCoords then
    baseCoords = a.renderCoords
  else
    if not a._physicsRenderCoords then
      a._physicsRenderCoords = { shape:getPoints() }
    end
    baseCoords = a._physicsRenderCoords
  end

  if a._targetOutlineCoords and a._targetOutlinePad == pad and a._targetOutlineBase == baseCoords then
    return a._targetOutlineCoords
  end

  a._targetOutlineCoords = buildExpandedOutlineCoords(baseCoords, pad)
  a._targetOutlinePad = pad
  a._targetOutlineBase = baseCoords
  return a._targetOutlineCoords
end

return Utils
