local Concord = require("lib.concord")
local MathUtil = require("util.math")

local MagnetSystem = Concord.system({
  pickups = { "pickup", "physics_body" },
})

local clamp = MathUtil.clamp

function MagnetSystem:init(world)
  self.world = world
end

local function getPlayerShip(world)
  local player = world and world:getResource("player")
  return player and player:has("pilot") and player.pilot.ship or nil
end

function MagnetSystem:fixedUpdate(dt)
  local world = self.world
  local ship = getPlayerShip(world)
  if ship == nil or not ship:has("magnet") or not ship:has("physics_body") then
    return
  end

  local shipBody = ship.physics_body.body
  if shipBody == nil then
    return
  end

  local magnet = ship.magnet
  local range = magnet.range or 0
  if range <= 0 then
    return
  end

  local strength = magnet.strength or 0
  local snapDistance = magnet.snapDistance or 0
  local maxSpeed = magnet.maxSpeed or 0

  local sx, sy = shipBody:getPosition()

  local range2 = range * range
  local snap2 = snapDistance * snapDistance
  local maxSpeed2 = maxSpeed * maxSpeed

  for i = 1, self.pickups.size do
    local e = self.pickups[i]
    local body = e and e.physics_body and e.physics_body.body
    if body ~= nil then
      local px, py = body:getPosition()
      local dx = sx - px
      local dy = sy - py
      local dist2 = dx * dx + dy * dy

      if dist2 > 0.0001 and dist2 <= range2 then
        if snapDistance > 0 and dist2 <= snap2 then
          -- Pickups don't contact the ship (collision-masked), so collection is driven by proximity.
          if world then
            world:emit("onAttemptCollect", ship, e)
          end
        else
          local dist = math.sqrt(dist2)
          local nx = dx / dist
          local ny = dy / dist

          local t = clamp(1 - (dist / range), 0, 1)
          local mass = body:getMass()
          local force = strength * (t * t) * mass
          body:applyForce(nx * force, ny * force)

          if maxSpeed > 0 then
            local vx, vy = body:getLinearVelocity()
            local speed2 = vx * vx + vy * vy
            if speed2 > maxSpeed2 then
              local inv = 1 / math.sqrt(speed2)
              body:setLinearVelocity(vx * inv * maxSpeed, vy * inv * maxSpeed)
            end
          end
        end
      end
    end
  end
end

return MagnetSystem
