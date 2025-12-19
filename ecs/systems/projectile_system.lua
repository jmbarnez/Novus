local Concord = require("lib.concord")
local Physics = require("ecs.util.physics")

local ProjectileSystem = Concord.system({
  projectiles = { "projectile", "physics_body" },
})

local function spawnExpireEffect(world, physicsWorld, x, y)
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

function ProjectileSystem:update(dt)
  for i = self.projectiles.size, 1, -1 do
    local e = self.projectiles[i]
    e.projectile.ttl = e.projectile.ttl - dt
    if e.projectile.ttl <= 0 then
      local body = e.physics_body and e.physics_body.body
      local world = e:getWorld()
      local physicsWorld = world and world:getResource("physics")

      if body and world then
        local x, y = body:getPosition()
        spawnExpireEffect(world, physicsWorld, x, y)
      end

      Physics.destroyPhysics(e)
      e:destroy()
    end
  end
end

return ProjectileSystem
