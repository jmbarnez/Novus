local Seed = {}

local MOD = 2147483647
local MUL = 48271

local function normalizeInt(n)
  n = math.floor(math.abs(tonumber(n) or 0))
  n = n % MOD
  if n == 0 then
    n = 1
  end
  return n
end

local function hashString(s)
  local h = 0
  for i = 1, #s do
    h = (h * 131 + s:byte(i)) % MOD
  end
  return normalizeInt(h)
end

function Seed.normalize(seed)
  return normalizeInt(seed)
end

function Seed.derive(worldSeed, salt)
  local h = normalizeInt(worldSeed)

  local saltNum
  if type(salt) == "number" then
    saltNum = normalizeInt(salt)
  else
    saltNum = hashString(tostring(salt))
  end

  h = (h + saltNum) % MOD
  if h == 0 then
    h = 1
  end

  h = (h * MUL) % MOD
  h = (h * MUL) % MOD

  if h == 0 then
    h = 1
  end

  return h
end

return Seed
