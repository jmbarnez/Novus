local Concord = require "lib.concord.concord"

local ExplosionSystem = Concord.system({
    pool = { "explosion", "lifetime", "transform" }
})

function ExplosionSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime
        if lifetime then
            lifetime.elapsed = (lifetime.elapsed or 0) + dt
            if lifetime.elapsed >= (lifetime.duration or 0) then
                if e.destroy then
                    e:destroy()
                else
                    local world = self:getWorld()
                    if world and world.removeEntity then
                        world:removeEntity(e)
                    end
                end
            end
        end
    end
end

return ExplosionSystem
