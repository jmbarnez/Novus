local Concord = require("lib.concord")
local Physics = require("ecs.util.physics")

local HealthSystem = Concord.system({
  entities = { "health" },
})

function HealthSystem:init(world)
  self.world = world
end

function HealthSystem:update()
  for i = self.entities.size, 1, -1 do
    local e = self.entities[i]

    if e.health.current > e.health.max then
      e.health.current = e.health.max
    end

    if e.health.current <= 0 then
      if self.world and e:has("asteroid") and e:has("physics_body") and e.physics_body.body then
        local x, y = e.physics_body.body:getPosition()
        local r = (e.asteroid and e.asteroid.radius) or 30
        self.world:emit("onAsteroidDestroyed", e, x, y, r)
      end
      Physics.destroyPhysics(e)

      e:destroy()
    end
  end
end

return HealthSystem
