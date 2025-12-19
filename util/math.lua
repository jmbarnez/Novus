local M = {}

function M.clamp(v, a, b)
  if v < a then
    return a
  end
  if v > b then
    return b
  end
  return v
end

function M.lerp(a, b, t)
  return a + (b - a) * t
end

function M.invLerp(a, b, v)
  if a == b then
    return 0
  end
  return (v - a) / (b - a)
end

function M.smoothstep(a, b, v)
  local t = M.clamp(M.invLerp(a, b, v), 0, 1)
  return t * t * (3 - 2 * t)
end

function M.randRange(a, b)
  return a + (b - a) * love.math.random()
end

function M.randSigned()
  return love.math.random() * 2 - 1
end

function M.randRangeRng(rng, a, b)
  return a + (b - a) * rng:random()
end

function M.randSignedRng(rng)
  return rng:random() * 2 - 1
end

function M.rotate(x, y, a)
  local ca = math.cos(a)
  local sa = math.sin(a)
  return x * ca - y * sa, x * sa + y * ca
end

function M.len2(x, y)
  return x * x + y * y
end

function M.dist2(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return dx * dx + dy * dy
end

function M.length(x, y)
  return math.sqrt(M.len2(x, y))
end

function M.normalize(x, y)
  local l2 = M.len2(x, y)
  if l2 <= 0.0000001 then
    return nil, nil, 0
  end

  local inv = 1 / math.sqrt(l2)
  return x * inv, y * inv, 1 / inv
end

function M.normalizeAngle(a)
  while a > math.pi do a = a - (math.pi * 2) end
  while a < -math.pi do a = a + (math.pi * 2) end
  return a
end

function M.atan2(y, x)
  -- LuaJIT/Lua 5.1 doesn't guarantee math.atan(y, x), so provide a stable atan2.
  if x > 0 then
    return math.atan(y / x)
  elseif x < 0 and y >= 0 then
    return math.atan(y / x) + math.pi
  elseif x < 0 and y < 0 then
    return math.atan(y / x) - math.pi
  elseif x == 0 and y > 0 then
    return math.pi / 2
  elseif x == 0 and y < 0 then
    return -math.pi / 2
  end

  return 0
end

return M
