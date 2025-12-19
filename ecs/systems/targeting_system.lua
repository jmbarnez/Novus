local Concord = require("lib.concord")

local TargetingSystem = Concord.system({
  targets = { "asteroid", "health", "physics_body" },
})

local function isValidTarget(e)
  return e
    and e.inWorld
    and e:inWorld()
    and e:has("health")
    and e.health.current > 0
    and e:has("physics_body")
end

function TargetingSystem:init(world)
  self.world = world

  local targeting = world:getResource("targeting")
  if not targeting then
    targeting = { hovered = nil, selected = nil }
    world:setResource("targeting", targeting)
  end

  self.targeting = targeting
end

function TargetingSystem:update()
  local world = self.world
  if not world then
    return
  end

  local uiCapture = world:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    self.targeting.hovered = nil
    return
  end

  local mw = world:getResource("mouse_world")
  if not mw then
    self.targeting.hovered = nil
    return
  end

  local best, bestDist2
  local mx, my = mw.x, mw.y

  for i = 1, self.targets.size do
    local e = self.targets[i]
    if isValidTarget(e) then
      local body = e.physics_body and e.physics_body.body
      if body then
        local x, y = body:getPosition()
        local dx = mx - x
        local dy = my - y
        local dist2 = dx * dx + dy * dy

        local r = (e.asteroid and e.asteroid.radius) or 30
        local pick = r + 14

        if dist2 <= (pick * pick) then
          if not bestDist2 or dist2 < bestDist2 then
            best = e
            bestDist2 = dist2
          end
        end
      end
    end
  end

  self.targeting.hovered = best

  local player = world:getResource("player")
  local ship = player and player:has("pilot") and player.pilot.ship or nil
  local weapon = ship and ship:has("auto_cannon") and ship.auto_cannon or nil
  local weaponTarget = weapon and weapon.target or nil

  if isValidTarget(weaponTarget) then
    self.targeting.selected = weaponTarget
  else
    if not isValidTarget(self.targeting.selected) then
      self.targeting.selected = nil
    end
  end
end

return TargetingSystem
