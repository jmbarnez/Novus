local M = {}

--- Ensure rng is a valid RandomGenerator, creating one if nil
---@param rng any Optional random generator
---@return love.math.RandomGenerator
function M.ensure(rng)
    if rng then
        return rng
    end
    return love.math.newRandomGenerator(love.math.random(1, 2147483646))
end

return M
