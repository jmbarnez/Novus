-- Railgun Turret Item Definition
return {
    id = "railgun",
    name = "Railgun Turret",
    description = "A high-velocity railgun turret. Punches through armor.",
    stackable = false,
    value = 200,
    type = "turret",
    volume = 0.4, -- 0.4 cubic meters for railgun
    module = require("src.turret_modules.railgun"),
    update = function(self, dt)
        -- Turret item update logic if needed
    end,
    onCollect = function(self, playerId)
        -- Hook for future expansion
    end
}
