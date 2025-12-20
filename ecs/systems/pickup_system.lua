local Concord = require("lib.concord")
local EntityUtil = require("ecs.util.entity")
local Physics = require("ecs.util.physics")
local MathUtil = require("util.math")
local Inventory = require("game.inventory")
local Items = require("game.items")
local FloatingText = require("ecs.util.floating_text")

local PickupSystem = Concord.system({
  ships = { "ship", "cargo", "cargo_hold", "physics_body" },
})

local function spawnStonePickup(world, physicsWorld, x, y, volume)
  if not world or not physicsWorld then
    return
  end

  local def = Items.get("stone")
  local color = (def and def.color) or { 0.7, 0.7, 0.7, 0.95 }

  local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
  body:setLinearDamping(3.5)
  body:setAngularDamping(6.0)

  local shape = love.physics.newCircleShape(6)
  local fixture = love.physics.newFixture(body, shape, 0.2)
  fixture:setSensor(true)
  fixture:setCategory(16)
  fixture:setMask(1, 2, 4, 8, 16)

  body:setLinearVelocity(MathUtil.randRange(-60, 60), MathUtil.randRange(-60, 60))

  local e = world:newEntity()
    :give("physics_body", body, shape, fixture)
    :give("renderable", "pickup", color)
    :give("pickup", "stone", volume)

  fixture:setUserData(e)
end

function PickupSystem:init(world)
  self.world = world
end

function PickupSystem:onAsteroidDestroyed(a, b, c, d)
  local world = self.world
  local physicsWorld = world and world:getResource("physics")
  if not physicsWorld then
    return
  end

  local asteroid = nil
  local x, y, radius
  if type(a) == "number" then
    x, y, radius = a, b, c
  else
    asteroid = a
    x, y, radius = b, c, d
  end

  local r = radius or (asteroid and asteroid.asteroid and asteroid.asteroid.radius) or 30
  local baseVolume = (asteroid and asteroid.asteroid and asteroid.asteroid.volume) or math.max(1, math.floor((r * r) / 50))
  local eff = (asteroid and asteroid.asteroid and asteroid.asteroid.lastMiningEfficiency) or 1.0
  eff = math.max(0, math.min(1, eff))

  local minedVolume = math.floor(baseVolume * eff)
  if minedVolume <= 0 then
    minedVolume = 1
  end

  local pieces = math.max(3, math.min(12, math.floor(r / 6)))
  local remaining = minedVolume

  for i = 1, pieces do
    if remaining <= 0 then
      break
    end

    local avg = math.max(1, math.floor(remaining / (pieces - i + 1)))
    local jitter = math.max(0, math.floor(avg * 0.6))
    local v = math.floor(MathUtil.randRange(avg - jitter, avg + jitter) + 0.5)
    if v < 1 then v = 1 end
    if v > remaining then v = remaining end
    remaining = remaining - v

    local jx = MathUtil.randRange(-10, 10)
    local jy = MathUtil.randRange(-10, 10)
    spawnStonePickup(world, physicsWorld, x + jx, y + jy, v)
  end

  while remaining > 0 do
    local v = math.min(3, remaining)
    remaining = remaining - v
    local jx = MathUtil.randRange(-10, 10)
    local jy = MathUtil.randRange(-10, 10)
    spawnStonePickup(world, physicsWorld, x + jx, y + jy, v)
  end
end

local function tryCollect(ship, pickup)
  if not ship or not pickup then
    return false
  end

  if not (ship:has("cargo") and ship:has("cargo_hold")) then
    return false
  end

  if not pickup:has("pickup") then
    return false
  end

  local p = pickup.pickup
  if not p.id or not p.volume or p.volume <= 0 then
    return false
  end

  local cap = ship.cargo.capacity or 0
  local used = ship.cargo.used or 0
  local free = cap - used
  if free <= 0 then
    return false
  end

  local tryVol = math.min(p.volume, free)
  if tryVol <= 0 then
    return false
  end

  local remaining = Inventory.addToSlots(ship.cargo_hold.slots, p.id, tryVol)
  local collected = tryVol - remaining
  if collected <= 0 then
    return false
  end

  do
    local world = ship:getWorld()
    local body = pickup.physics_body and pickup.physics_body.body
    if world and body then
      local x, y = body:getPosition()
      local def = Items.get(p.id)
      local name = (def and def.name) or p.id
      FloatingText.spawnStacked(world, x, y - 10, "pickup:" .. tostring(p.id), collected, {
        kind = "pickup",
        stackLabel = name,
        prefix = "+",
        stackRadius = 80,
        stackWindow = 0.4,
        riseSpeed = 55,
        duration = 0.75,
        scale = 0.95,
      })
    end
  end

  ship.cargo.used = Inventory.totalVolume(ship.cargo_hold.slots)

  local leftoverPickupVol = p.volume - collected
  if leftoverPickupVol <= 0 then
    Physics.destroyPhysics(pickup)
    pickup:destroy()
  else
    p.volume = leftoverPickupVol
  end

  return true
end

function PickupSystem:onAttemptCollect(ship, pickup)
  if not EntityUtil.isAlive(ship) or not EntityUtil.isAlive(pickup) then
    return
  end

  tryCollect(ship, pickup)
end

function PickupSystem:onContact(a, b, contact)
  if not EntityUtil.isAlive(a) or not EntityUtil.isAlive(b) then
    return
  end

  if EntityUtil.isAliveAndHas(a, "pickup") then
    for i = 1, self.ships.size do
      local ship = self.ships[i]
      if ship and ship:has("physics_body") and ship.physics_body.body and b == ship then
        if tryCollect(ship, a) then
          return
        end
      end
    end
  end

  if EntityUtil.isAliveAndHas(b, "pickup") then
    for i = 1, self.ships.size do
      local ship = self.ships[i]
      if ship and ship:has("physics_body") and ship.physics_body.body and a == ship then
        if tryCollect(ship, b) then
          return
        end
      end
    end
  end
end

return PickupSystem
