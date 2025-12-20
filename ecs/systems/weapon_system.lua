local Concord = require("lib.concord")
local Math = require("util.math")

-- Localize frequently used functions
local clamp = Math.clamp
local normalizeAngle = Math.normalizeAngle
local atan2 = Math.atan2
local cos, sin, sqrt, max, min, pi = math.cos, math.sin, math.sqrt, math.max, math.min, math.pi

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
-- Target Validation
--------------------------------------------------------------------------------

local function isValidTarget(e)
  return e
    and e.inWorld
    and e:inWorld()
    and e:has("health")
    and e.health.current > 0
    and e:has("physics_body")
end

--------------------------------------------------------------------------------
-- Aiming Helpers
--------------------------------------------------------------------------------

local function getClampedAimDir(shipBody, dx, dy, coneHalfAngle)
  local dist2 = dx * dx + dy * dy
  if dist2 <= 0.0001 then
    return nil
  end

  local dist = sqrt(dist2)
  local dirX, dirY = dx / dist, dy / dist

  -- No cone restriction
  if not coneHalfAngle or coneHalfAngle >= pi then
    return dirX, dirY
  end

  -- Clamp aim direction within firing cone
  local shipAngle = shipBody:getAngle()
  local aimAngle = atan2(dirY, dirX)
  local delta = normalizeAngle(aimAngle - shipAngle)
  local clampedDelta = clamp(delta, -coneHalfAngle, coneHalfAngle)
  local finalAngle = shipAngle + clampedDelta

  return cos(finalAngle), sin(finalAngle)
end

--------------------------------------------------------------------------------
-- Projectile Spawning
--------------------------------------------------------------------------------

local function getMuzzlePosition(shipBody, dirX, dirY)
  local sx, sy = shipBody:getPosition()
  local muzzleOffset = 18
  return sx + dirX * muzzleOffset, sy + dirY * muzzleOffset
end

local function spawnProjectile(world, physicsWorld, ship, weapon, dirX, dirY)
  local shipBody = ship.physics_body.body
  local muzzleX, muzzleY = getMuzzlePosition(shipBody, dirX, dirY)

  -- Create physics body
  local body = love.physics.newBody(physicsWorld, muzzleX, muzzleY, "dynamic")
  body:setBullet(true)
  body:setLinearDamping(0)
  body:setAngularDamping(0)
  if body.setGravityScale then
    body:setGravityScale(0)
  end

  -- Create shape and fixture
  local shape = love.physics.newCircleShape(2)
  local fixture = love.physics.newFixture(body, shape, 0.1)
  fixture:setSensor(true)
  fixture:setCategory(4)
  fixture:setMask(2, 4)

  -- Set velocity
  local speed = weapon.projectileSpeed or 1200
  body:setLinearVelocity(dirX * speed, dirY * speed)

  -- Calculate time-to-live
  local ttl = weapon.projectileTtl or 1.2
  if weapon.range and weapon.range > 0 and speed > 0 then
    ttl = min(ttl, weapon.range / speed)
  end

  -- Create projectile entity
  local miningEfficiency = weapon.miningEfficiency or 1.0
  local projectile = world:newEntity()
    :give("physics_body", body, shape, fixture)
    :give("renderable", "projectile", { 0.00, 1.00, 1.00, 0.95 })
    :give("projectile", weapon.damage, ttl, ship, miningEfficiency)

  fixture:setUserData(projectile)
  return true
end

--------------------------------------------------------------------------------
-- Firing Logic
--------------------------------------------------------------------------------

local function triggerConeVisual(weapon)
  local hold = weapon.coneVisHold or 0
  local fade = weapon.coneVisFade or 0
  if hold + fade > 0 then
    weapon.coneVis = hold + fade
  end
end

local function fireWeapon(world, physicsWorld, ship, weapon, targetX, targetY)
  if weapon.timer > 0 then
    return false
  end

  local shipBody = ship.physics_body.body
  local sx, sy = shipBody:getPosition()
  local dx, dy = targetX - sx, targetY - sy

  local dirX, dirY = getClampedAimDir(shipBody, dx, dy, weapon.coneHalfAngle)
  if not dirX then
    return false
  end

  weapon.timer = weapon.cooldown
  triggerConeVisual(weapon)

  return spawnProjectile(world, physicsWorld, ship, weapon, dirX, dirY)
end

local function fireAtTarget(world, physicsWorld, ship, weapon, target)
  if not isValidTarget(target) then
    return false
  end

  local tx, ty = target.physics_body.body:getPosition()
  return fireWeapon(world, physicsWorld, ship, weapon, tx, ty)
end

local function fireAtPosition(world, physicsWorld, ship, weapon, worldX, worldY)
  return fireWeapon(world, physicsWorld, ship, weapon, worldX, worldY)
end

local function drawAimIndicator(sx, sy, aimX, aimY)
  local dx, dy = aimX - sx, aimY - sy
  if (dx * dx + dy * dy) <= 0.0001 then
    return
  end

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 10.0))

  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.10 * pulse)
  love.graphics.line(sx, sy, aimX, aimY)

  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.28)
  love.graphics.line(sx, sy, aimX, aimY)

  local r = 10
  local len = 7
  local gap = 3

  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.12 * pulse)
  love.graphics.circle("line", aimX, aimY, r)
  love.graphics.line(aimX - (gap + len), aimY, aimX - gap, aimY)
  love.graphics.line(aimX + gap, aimY, aimX + (gap + len), aimY)
  love.graphics.line(aimX, aimY - (gap + len), aimX, aimY - gap)
  love.graphics.line(aimX, aimY + gap, aimX, aimY + (gap + len))

  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.35)
  love.graphics.circle("line", aimX, aimY, r)
  love.graphics.line(aimX - (gap + len), aimY, aimX - gap, aimY)
  love.graphics.line(aimX + gap, aimY, aimX + (gap + len), aimY)
  love.graphics.line(aimX, aimY - (gap + len), aimX, aimY - gap)
  love.graphics.line(aimX, aimY + gap, aimX, aimY + (gap + len))

  love.graphics.setBlendMode(bm, am)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)
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

  local dirX, dirY = getClampedAimDir(body, dx, dy, weapon.coneHalfAngle)
  if not dirX then
    return
  end

  local dist = sqrt(dx * dx + dy * dy)
  if weapon.range and weapon.range > 0 then
    dist = min(dist, weapon.range)
  end

  local muzzleX, muzzleY = getMuzzlePosition(body, dirX, dirY)

  local mdx, mdy = mw.x - muzzleX, mw.y - muzzleY
  dist = sqrt(mdx * mdx + mdy * mdy)
  if weapon.range and weapon.range > 0 then
    dist = min(dist, weapon.range)
  end

  local aimX = muzzleX + dirX * dist
  local aimY = muzzleY + dirY * dist
  drawAimIndicator(muzzleX, muzzleY, aimX, aimY)
end

function WeaponSystem:drawWeaponCone(body, weapon)
  -- Check if cone should be visible
  if not weapon.coneVis or weapon.coneVis <= 0 then
    return
  end
  if not weapon.coneHalfAngle or weapon.coneHalfAngle <= 0 or weapon.coneHalfAngle >= pi then
    return
  end

  local x, y = body:getPosition()
  local a = body:getAngle()
  local r = weapon.coneVisLen or 0
  if r <= 0 then
    return
  end

  local halfAngle = weapon.coneHalfAngle

  -- Calculate fade alpha
  local fade = weapon.coneVisFade or 0
  local alpha = 1
  if fade > 0 and weapon.coneVis <= fade then
    alpha = clamp(weapon.coneVis / fade, 0, 1)
  end

  -- Calculate cone boundary points
  local ax1 = x + cos(a - halfAngle) * r
  local ay1 = y + sin(a - halfAngle) * r
  local ax2 = x + cos(a + halfAngle) * r
  local ay2 = y + sin(a + halfAngle) * r

  local t = love.timer.getTime()
  local pulse = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 8.0))

  local bm, am = love.graphics.getBlendMode()
  love.graphics.setBlendMode("add", "alphamultiply")
  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.10 * alpha * pulse)
  love.graphics.line(x, y, ax1, ay1)
  love.graphics.line(x, y, ax2, ay2)

  love.graphics.setBlendMode(bm, am)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.20, 0.85, 1.00, 0.18 * alpha)
  love.graphics.line(x, y, ax1, ay1)
  love.graphics.line(x, y, ax2, ay2)

  love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Target Selection
--------------------------------------------------------------------------------

function WeaponSystem:findTargetAtPosition(worldX, worldY)
  local best = nil
  local bestDist2 = nil

  for i = 1, self.targets.size do
    local e = self.targets[i]
    if isValidTarget(e) then
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
  if not isValidTarget(target) then
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
      if isValidTarget(hoverTarget) then
        fireAtTarget(self.world, physicsWorld, ship, weapon, hoverTarget)
      elseif target then
        fireAtTarget(self.world, physicsWorld, ship, weapon, target)
      else
        fireAtPosition(self.world, physicsWorld, ship, weapon, mw.x, mw.y)
      end
    end
  end
end

return WeaponSystem
