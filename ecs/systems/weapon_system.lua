local Concord = require("lib.concord")
local WeaponLogic = require("ecs.systems.weapon_logic")
local WeaponDraw = require("ecs.systems.draw.weapon_draw")

-- Localize frequently used functions
local sqrt, max, min = math.sqrt, math.max, math.min

local WeaponSystem = Concord.system({
  targets = { "asteroid", "health", "physics_body" },
})

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function WeaponSystem:init(world)
  self.world = world
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

function WeaponSystem:drawWorld()
  local player = self.world:getResource("player")
  if not player or not player:has("pilot") then
    return
  end

  local ship = player.pilot.ship
  if not ship or not ship:has("auto_cannon") or not ship:has("physics_body") then
    return
  end

  local weapon = ship.auto_cannon
  local body = ship.physics_body.body
  if not body then
    return
  end

  local uiCapture = self.world and self.world:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    return
  end

  if not love.mouse.isDown(2) then
    return
  end

  local mw = self.world:getResource("mouse_world")
  if not mw then
    return
  end

  local sx, sy = body:getPosition()
  local dx, dy = mw.x - sx, mw.y - sy

  local dirX, dirY = WeaponLogic.getClampedAimDir(body, dx, dy, weapon.coneHalfAngle)
  if not dirX then
    return
  end

  local dist = sqrt(dx * dx + dy * dy)
  if weapon.range and weapon.range > 0 then
    dist = min(dist, weapon.range)
  end

  local muzzleX, muzzleY = WeaponLogic.getMuzzlePosition(body, dirX, dirY)

  local mdx, mdy = mw.x - muzzleX, mw.y - muzzleY
  dist = sqrt(mdx * mdx + mdy * mdy)
  if weapon.range and weapon.range > 0 then
    dist = min(dist, weapon.range)
  end

  local aimX = muzzleX + dirX * dist
  local aimY = muzzleY + dirY * dist
  WeaponDraw.drawAimIndicator(muzzleX, muzzleY, aimX, aimY)
end

function WeaponSystem:drawWeaponCone(body, weapon)
  return WeaponDraw.drawWeaponCone(body, weapon)
end

--------------------------------------------------------------------------------
-- Target Selection
--------------------------------------------------------------------------------

function WeaponSystem:findTargetAtPosition(worldX, worldY)
  local best = nil
  local bestDist2 = nil

  for i = 1, self.targets.size do
    local e = self.targets[i]
    if WeaponLogic.isValidTarget(e) then
      local tx, ty = e.physics_body.body:getPosition()
      local dx, dy = tx - worldX, ty - worldY
      local dist2 = dx * dx + dy * dy

      local radius = (e.asteroid and e.asteroid.radius) or 30
      local pickRadius = max(18, radius)

      if dist2 <= pickRadius * pickRadius then
        if not bestDist2 or dist2 < bestDist2 then
          best = e
          bestDist2 = dist2
        end
      end
    end
  end

  return best
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

function WeaponSystem:onTargetClick(worldX, worldY, button)
  if button ~= 1 then
    return
  end

  local uiCapture = self.world and self.world:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    return
  end

  if not love.keyboard.isDown("lctrl", "rctrl") then
    return
  end

  local player = self.world:getResource("player")
  if not player or not player:has("pilot") then
    return
  end

  local ship = player.pilot.ship
  if not ship or not ship:has("auto_cannon") or not ship:has("physics_body") then
    return
  end

  local physicsWorld = self.world:getResource("physics")
  if not physicsWorld then
    return
  end

  local weapon = ship.auto_cannon
  local target = self:findTargetAtPosition(worldX, worldY)
  weapon.target = target
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

function WeaponSystem:update(dt)
  local player = self.world:getResource("player")
  if not player or not player:has("pilot") then
    return
  end

  local uiCapture = self.world and self.world:getResource("ui_capture")
  if uiCapture and uiCapture.active then
    return
  end

  local physicsWorld = self.world:getResource("physics")
  if not physicsWorld then
    return
  end

  local ship = player.pilot.ship
  if not ship or not ship:has("auto_cannon") or not ship:has("physics_body") then
    return
  end

  local weapon = ship.auto_cannon

  -- Update timers
  weapon.timer = max(0, weapon.timer - dt)
  if weapon.coneVis then
    weapon.coneVis = max(0, weapon.coneVis - dt)
  end

  -- Validate current target
  local target = weapon.target
  if not WeaponLogic.isValidTarget(target) then
    weapon.target = nil
    target = nil
  else
    local shipPb = ship.physics_body
    local targetPb = (target and target.physics_body) or nil
    local shipBody = (shipPb and shipPb.body) or nil
    local targetBody = (targetPb and targetPb.body) or nil
    if not shipBody or not targetBody then
      weapon.target = nil
      target = nil
    elseif weapon.range and weapon.range > 0 then
      local sx, sy = shipBody:getPosition()
      local tx, ty = targetBody:getPosition()
      local dx, dy = tx - sx, ty - sy
      local dist2 = dx * dx + dy * dy
      local maxDist2 = weapon.range * weapon.range

      if dist2 > maxDist2 then
        weapon.target = nil
        target = nil
      end
    end
  end

  if love.mouse.isDown(1) and weapon.timer <= 0 then
    if love.keyboard.isDown("lctrl", "rctrl") then
      return
    end

    local mw = self.world:getResource("mouse_world")
    if mw then
      local hoverTarget = self:findTargetAtPosition(mw.x, mw.y)
      if WeaponLogic.isValidTarget(hoverTarget) then
        WeaponLogic.fireAtTarget(self.world, physicsWorld, ship, weapon, hoverTarget)
      elseif target then
        WeaponLogic.fireAtTarget(self.world, physicsWorld, ship, weapon, target)
      else
        WeaponLogic.fireAtPosition(self.world, physicsWorld, ship, weapon, mw.x, mw.y)
      end
    end
  end
end

return WeaponSystem
