local ECS = require('src.ecs')

local AbilitySystem = {
    name = "AbilitySystem",
    priority = 105
}

function AbilitySystem.update(dt)
    local abilities = ECS.getEntitiesWith({"Ability", "Position"})
    for _, abilityId in ipairs(abilities) do
        local ability = ECS.getComponent(abilityId, "Ability")
        if ability then
            local lifetime = ECS.getComponent(abilityId, "ProjectileLifetime")
            local expired = false
            if lifetime then
                lifetime.age = (lifetime.age or 0) + dt
                if lifetime.age >= (lifetime.maxAge or 0) then
                    expired = true
                end
            end

            if expired then
                -- Clear ActiveMirror on owner if present (for mirror type)
                if ability.abilityType == "mirror" and ability.ownerId and ECS.hasComponent(ability.ownerId, "ActiveMirror") then
                    local am = ECS.getComponent(ability.ownerId, "ActiveMirror")
                    if am and am.id == abilityId then
                        ECS.removeComponent(ability.ownerId, "ActiveMirror")
                    end
                end
                ECS.destroyEntity(abilityId)
            end
        end
    end
end

return AbilitySystem
