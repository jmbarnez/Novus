local Concord = require("lib.concord")
local Math = require("util.math")

local clamp = Math.clamp
local normalizeAngle = Math.normalizeAngle
local atan2 = Math.atan2
local cos, sin, sqrt, min, pi = math.cos, math.sin, math.sqrt, math.min, math.pi

local WeaponLogic = {}

function WeaponLogic.isValidTarget(e)
  return e
    and e.inWorld
    and e:inWorld()
    and e:has("health")
    and e.health.current > 0
    and e:has("physics_body")
end

function WeaponLogic.getClampedAimDir(shipBody, dx, dy, coneHalfAngle)
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

function WeaponLogic.getMuzzlePosition(shipBody, dirX, dirY)
  local sx, sy = shipBody:getPosition()
  local muzzleOffset = 18
  return sx + dirX * muzzleOffset, sy + dirY * muzzleOffset
end

local function spawnProjectile(world, physicsWorld, ship, weapon, dirX, dirY)
  local shipBody = ship.physics_body.body
  local muzzleX, muzzleY = WeaponLogic.getMuzzlePosition(shipBody, dirX, dirY)

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

local function triggerConeVisual(weapon)
  local hold = weapon.coneVisHold or 0
  local fade = weapon.coneVisFade or 0
  if hold + fade > 0 then
    weapon.coneVis = hold + fade
  end
end

function WeaponLogic.fireWeapon(world, physicsWorld, ship, weapon, targetX, targetY)
  if weapon.timer > 0 then
    return false
  end

  local shipBody = ship.physics_body.body
  local sx, sy = shipBody:getPosition()
  local dx, dy = targetX - sx, targetY - sy

  local dirX, dirY = WeaponLogic.getClampedAimDir(shipBody, dx, dy, weapon.coneHalfAngle)
  if not dirX then
    return false
  end

  weapon.timer = weapon.cooldown
  triggerConeVisual(weapon)

  return spawnProjectile(world, physicsWorld, ship, weapon, dirX, dirY)
end

function WeaponLogic.fireAtTarget(world, physicsWorld, ship, weapon, target)
  if not WeaponLogic.isValidTarget(target) then
    return false
  end

  local tx, ty = target.physics_body.body:getPosition()
  return WeaponLogic.fireWeapon(world, physicsWorld, ship, weapon, tx, ty)
end

function WeaponLogic.fireAtPosition(world, physicsWorld, ship, weapon, worldX, worldY)
  return WeaponLogic.fireWeapon(world, physicsWorld, ship, weapon, worldX, worldY)
end

return WeaponLogic
