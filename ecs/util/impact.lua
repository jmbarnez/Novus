local M = {}
local MathUtil = require("util.math")

function M.getContactPosition(contact)
  if contact == nil or contact.getPositions == nil then
    return nil, nil
  end

  local x1, y1, x2, y2 = contact:getPositions()
  if x1 ~= nil then
    return x1, y1
  end

  return x2, y2
end

function M.getBackDistance(target)
  if target:has("asteroid") and target.asteroid.radius then
    return target.asteroid.radius
  end

  return 24
end

function M.getBodyDirection(body)
  local vx, vy = body:getLinearVelocity()
  local nx, ny = MathUtil.normalize(vx, vy)
  return nx, ny
end

function M.raycastToTarget(physicsWorld, px, py, nx, ny, maxDist, target)
  if not physicsWorld or not physicsWorld.rayCast then
    return nil, nil
  end

  local hitX, hitY

  physicsWorld:rayCast(
    px, py,
    px - nx * maxDist, py - ny * maxDist,
    function(fixture, hx, hy, _, _, fraction)
      local userData = fixture and fixture.getUserData and fixture:getUserData()
      if userData == target then
        hitX, hitY = hx, hy
        return fraction
      end

      return -1
    end
  )

  return hitX, hitY
end

function M.estimateImpactFromVelocity(physicsWorld, body, target, backDist)
  local px, py = body:getPosition()
  local nx, ny = M.getBodyDirection(body)

  if nx == nil then
    return nil, nil
  end

  local maxDist = backDist * 2 + 30
  local hitX, hitY = M.raycastToTarget(physicsWorld, px, py, nx, ny, maxDist, target)
  if hitX ~= nil then
    return hitX, hitY
  end

  return px - nx * backDist, py - ny * backDist
end

function M.estimateImpactFromTargetPosition(body, target, backDist)
  local px, py = body:getPosition()

  if not target:has("physics_body") or not target.physics_body.body then
    return px, py
  end

  local ax, ay = target.physics_body.body:getPosition()
  local dx, dy = px - ax, py - ay
  local len2 = MathUtil.len2(dx, dy)

  if len2 <= 0.001 then
    return px, py
  end

  local nx, ny = MathUtil.normalize(dx, dy)
  return ax + nx * backDist, ay + ny * backDist
end

function M.calculateImpactPosition(projectile, target, contact)
  local x, y = M.getContactPosition(contact)
  if x ~= nil then
    return x, y
  end

  local body = projectile.physics_body.body
  local world = projectile:getWorld()
  local physicsWorld = world and world:getResource("physics")
  local backDist = M.getBackDistance(target)

  local nx, _ = M.getBodyDirection(body)
  if nx ~= nil then
    return M.estimateImpactFromVelocity(physicsWorld, body, target, backDist)
  end

  return M.estimateImpactFromTargetPosition(body, target, backDist)
end

return M
