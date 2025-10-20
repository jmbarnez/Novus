-- src/noise.lua
-- Simple Perlin noise implementation for nebula generation
-- Source: https://github.com/vrld/luanoise (MIT License, simplified)

local Noise = {}

local perm = {}
for i = 1, 256 do perm[i] = math.random(0, 255) end
for i = 257, 512 do perm[i] = perm[i - 256] end

local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end
local function lerp(a, b, t)
    return a + t * (b - a)
end
local function grad(hash, x, y)
    local h = hash % 4
    if h == 0 then return  x + y end
    if h == 1 then return -x + y end
    if h == 2 then return  x - y end
    return -x - y
end

function Noise.perlin(x, y, seed)
    seed = seed or 0
    x = x + seed
    y = y + seed
    local xi = math.floor(x) % 256 + 1
    local yi = math.floor(y) % 256 + 1
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)
    local u = fade(xf)
    local v = fade(yf)
    local aa = perm[perm[xi] + yi]
    local ab = perm[perm[xi] + yi + 1]
    local ba = perm[perm[xi + 1] + yi]
    local bb = perm[perm[xi + 1] + yi + 1]
    local x1 = lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u)
    local x2 = lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u)
    return (lerp(x1, x2, v) + 1) / 2 -- Normalize to [0,1]
end

return Noise
