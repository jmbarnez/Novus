local Concord = require("lib.concord")
local EntityUtil = require("ecs.util.entity")

local ContactFlashSystem = Concord.system()

function ContactFlashSystem:onContact(a, b, contact)
  if EntityUtil.isAliveAndHas(a, "renderable") then
    a:ensure("hit_flash")
    a.hit_flash.t = a.hit_flash.duration
  end

  if EntityUtil.isAliveAndHas(b, "renderable") then
    b:ensure("hit_flash")
    b.hit_flash.t = b.hit_flash.duration
  end
end

return ContactFlashSystem
