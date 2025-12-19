local M = {}

function M.isAlive(e)
  return e ~= nil and e.inWorld ~= nil and e:inWorld()
end

function M.isAliveAndHas(e, ...)
  if not M.isAlive(e) then
    return false
  end

  for i = 1, select("#", ...) do
    local c = select(i, ...)
    if not e:has(c) then
      return false
    end
  end

  return true
end

return M
