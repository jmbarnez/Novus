
local ECS = require('src.ecs')
local Components = require('src.components')

local Railgun = {
	name = "railgun",
	displayName = "Railgun Turret",
	SLUG_SPEED = 700,
	SLUG_WIDTH = 10,
	SLUG_HEIGHT = 3,
	SLUG_COLOR = {0.6, 0.9, 1, 1},
	SLUG_LIFETIME = 8,
	COOLDOWN = 3,
	DPS = 30,
	design = {
		shape = "custom",
		size = 18,
		color = {0.6, 0.8, 1, 1}
	},
	draw = function(self, x, y)
		local size = self.design.size
		love.graphics.setColor(0.2, 0.2, 0.3, 1)
		love.graphics.rectangle("fill", x - size/4, y - size/2, size/2, size, 4, 4)
		love.graphics.setColor(0.6, 0.8, 1, 1)
		love.graphics.circle("fill", x, y + size/2, size/3)
		love.graphics.setColor(0.3, 0.3, 0.4, 1)
		love.graphics.rectangle("fill", x - size/2, y + size/3, size, size/4, 4, 4)
	end
}

function Railgun.fire(ownerId, startX, startY, endX, endY)
	-- Calculate direction
	local dx = endX - startX
	local dy = endY - startY
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist == 0 then return end
	local dirX = dx / dist
	local dirY = dy / dist

	local ownerCollidable = ECS.getComponent(ownerId, "Collidable")
	local barrelOffset = ownerCollidable and (ownerCollidable.radius + Railgun.SLUG_WIDTH + 6) or 24
	local spawnX = startX + dirX * barrelOffset
	local spawnY = startY + dirY * barrelOffset

	local slugId = ECS.createEntity()
	ECS.addComponent(slugId, "Position", Components.Position(spawnX, spawnY))
	ECS.addComponent(slugId, "Velocity", Components.Velocity(dirX * Railgun.SLUG_SPEED, dirY * Railgun.SLUG_SPEED))
	ECS.addComponent(slugId, "Renderable", Components.Renderable("rectangle", Railgun.SLUG_WIDTH, Railgun.SLUG_HEIGHT, nil, Railgun.SLUG_COLOR))
	ECS.addComponent(slugId, "Collidable", Components.Collidable(math.max(Railgun.SLUG_WIDTH, Railgun.SLUG_HEIGHT)))
	ECS.addComponent(slugId, "Projectile", {ownerId = ownerId, damage = Railgun.DPS, brittle = false, isMissile = false, penetration = true})
	ECS.addComponent(slugId, "ProjectileLifetime", {age = 0, maxAge = Railgun.SLUG_LIFETIME})
end

return Railgun
