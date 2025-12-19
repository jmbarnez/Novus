local Concord = require("lib.concord")

local LaserBeamSystem = Concord.system({
  beams = { "laser_beam" },
})

function LaserBeamSystem:update(dt)
  for i = self.beams.size, 1, -1 do
    local e = self.beams[i]
    e.laser_beam.t = e.laser_beam.t - dt
    if e.laser_beam.t <= 0 then
      e:remove("laser_beam")
    end
  end
end

return LaserBeamSystem
