local ship = {}

local Inventory = require("game.inventory")

function ship.createShip(ecsWorld, physicsWorld, x, y)
  local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
  body:setLinearDamping(0.15)
  body:setAngularDamping(6.0)
  body:setBullet(true)

  local shape = love.physics.newPolygonShape(
    12, 0,
    6, 5,
    0, 10,
    -10, 5,
    -12, 0,
    -10, -5,
    0, -10,
    6, -5
  )

  local fixture = love.physics.newFixture(body, shape, 1)
  fixture:setDensity(4)
  body:resetMassData()
  fixture:setRestitution(0.2)
  fixture:setFriction(0.4)

  fixture:setCategory(2)

  local e = ecsWorld:newEntity()
      :give("physics_body", body, shape, fixture)
      :give("renderable", "ship", { 0.75, 0.85, 1.0, 1.0 })
      :give("ship")
      :give("ship_control", {
        thrustForce = 220,
        strafeForce = 180,
        rcsPower = 400,
        stabilization = 1.0,
      })
      :give("ship_input")
      :give("auto_cannon")
      :give("engine_trail", {
        offsetX = -12,
        offsetY = 0,
        color = { 0.00, 1.00, 1.00, 0.95 },
      })
      :give("cargo", 100)
      :give("cargo_hold", 4, 4)
      :give("magnet", 360, 140, 30, 420)
      :give("hull", 100)
      :give("shield", 60, 0)
      :give("energy", 100, 0)

  fixture:setUserData(e)

  if e.cargo and e.cargo_hold and e.cargo_hold.slots then
    e.cargo.used = Inventory.totalVolume(e.cargo_hold.slots)
  end

  return e
end

return ship
