local Rendering = require('src.components.rendering')

local function assertAlmostEqual(a, b, eps, msg)
    eps = eps or 1e-12
    if math.abs(a - b) > eps then
        error(msg or string.format('Expected %.17f to equal %.17f (±%.2g)', a, b, eps))
    end
end

-- The nebula generator chooses a seed using math.random when none is provided.
-- Verify that invoking it does not disturb the global RNG sequence beyond
-- consuming that one random value.
math.randomseed(12345)
Rendering.NebulaCloud(0, 0, 100)
local after = {math.random(), math.random(), math.random()}

math.randomseed(12345)
math.random(1000000) -- NebulaCloud consumes one random number to pick a seed.
local expected = {math.random(), math.random(), math.random()}

for i = 1, #after do
    assertAlmostEqual(after[i], expected[i], 1e-12, 'Random sequence diverged after nebula generation')
end

print('Nebula cloud RNG isolation test passed')
