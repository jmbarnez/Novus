local M = {}

local function isDestroyed(obj)
  return obj ~= nil and obj.isDestroyed ~= nil and obj:isDestroyed()
end

function M.destroyPhysics(e)
  if e == nil or e.has == nil or not e:has("physics_body") then
    return
  end

  local pb = e.physics_body
  if pb == nil then
    return
  end

  local fixture = pb.fixture
  if fixture and fixture.setUserData then
    fixture:setUserData(nil)
  end

  if fixture and fixture.destroy and not isDestroyed(fixture) then
    fixture:destroy()
  end

  local body = pb.body
  if body and body.destroy and not isDestroyed(body) then
    body:destroy()
  end

  pb.body = nil
  pb.shape = nil
  pb.fixture = nil
end

function M.destroyEntityPhysics(e)
  return M.destroyPhysics(e)
end

return M
