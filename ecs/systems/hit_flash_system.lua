local Concord = require("lib.concord")

local HitFlashSystem = Concord.system({
  flashed = { "hit_flash" },
})

function HitFlashSystem:update(dt)
  for i = self.flashed.size, 1, -1 do
    local e = self.flashed[i]
    e.hit_flash.t = e.hit_flash.t - dt
    if e.hit_flash.t <= 0 then
      e:remove("hit_flash")
    end
  end
end

return HitFlashSystem
