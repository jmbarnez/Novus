local Concord = require("lib.concord")
local PhysicsCleanup = require("ecs.physics_cleanup")
local EntityUtil = require("ecs.util.entity")
local ImpactUtil = require("ecs.util.impact")
local FloatingText = require("ecs.util.floating_text")

local ProjectileHitSystem = Concord.system()

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------

local function isValidProjectile(projectile)
  return EntityUtil.isAliveAndHas(projectile, "projectile")
end

local function isValidTarget(projectile, target)
  if not EntityUtil.isAlive(target) then
    return false
  end

  if not target:has("health") then
    return false
  end

  -- Prevent self-damage
  local owner = projectile.projectile.owner
  if owner ~= nil and owner == target then
    return false
  end

  return true
end

--------------------------------------------------------------------------------
-- Visual effects
--------------------------------------------------------------------------------

local function spawnImpactEffect(world, physicsWorld, x, y)
  if not physicsWorld then
    return
  end

  local effectBody = love.physics.newBody(physicsWorld, x, y, "static")
  local effectShape = love.physics.newCircleShape(1)
  local effectFixture = love.physics.newFixture(effectBody, effectShape, 0)

  effectFixture:setSensor(true)
  effectFixture:setCategory(8)
  effectFixture:setMask(1, 2, 4, 8)

  world:newEntity()
    :give("physics_body", effectBody, effectShape, effectFixture)
    :give("renderable", "shatter", { 1, 1, 1, 1 })
    :give("shatter")
end

--------------------------------------------------------------------------------
-- Damage application
--------------------------------------------------------------------------------

local function applyDamage(target, damage)
  target.health.current = target.health.current - damage
  target:ensure("hit_flash")
  target.hit_flash.t = target.hit_flash.duration
end

--------------------------------------------------------------------------------
-- Main hit processing
--------------------------------------------------------------------------------

local function tryHit(projectile, target, contact)
  if not isValidProjectile(projectile) then
    return
  end

  if not isValidTarget(projectile, target) then
    return
  end

  local damage = projectile.projectile.damage or 1
  applyDamage(target, damage)

  if target:has("asteroid") then
    local eff = projectile.projectile.miningEfficiency
    if eff == nil then
      eff = 1.0
    end
    target.asteroid.lastMiningEfficiency = eff
  end

  if projectile:has("physics_body") and projectile.physics_body.body then
    local world = projectile:getWorld()
    local physicsWorld = world and world:getResource("physics")
    local x, y = ImpactUtil.calculateImpactPosition(projectile, target, contact)

    spawnImpactEffect(world, physicsWorld, x, y)

    if world then
      FloatingText.spawn(world, x, y - 6, tostring(damage), {
        kind = "damage",
        riseSpeed = 70,
        duration = 0.55,
        scale = 1.0,
      })
    end
  end

  PhysicsCleanup.destroyPhysics(projectile)
  projectile:destroy()
end

--------------------------------------------------------------------------------
-- System callbacks
--------------------------------------------------------------------------------

function ProjectileHitSystem:onContact(a, b, contact)
  tryHit(a, b, contact)
  tryHit(b, a, contact)
end

return ProjectileHitSystem
