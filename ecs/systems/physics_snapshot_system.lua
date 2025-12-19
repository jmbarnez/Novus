local Concord = require("lib.concord")

local PhysicsSnapshotSystem = Concord.system({
  bodies = { "physics_body" },
})

function PhysicsSnapshotSystem:init(world)
  self.world = world
end

function PhysicsSnapshotSystem:fixedUpdate()
  for i = 1, self.bodies.size do
    local e = self.bodies[i]
    local pb = e.physics_body
    local body = pb and pb.body
    if body then
      local x, y = body:getPosition()
      pb.prevX = x
      pb.prevY = y
      pb.prevA = body:getAngle()
    end
  end
end

return PhysicsSnapshotSystem
