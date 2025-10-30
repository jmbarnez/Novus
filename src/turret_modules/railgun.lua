local ECS = require('src.ecs')
local Components = require('src.components')


local Railgun = {
	id = "railgun",
	name = "railgun",
	displayName = "Railgun Turret",
	description = "A high-velocity railgun turret. Punches through armor.",
	stackable = false,
	value = 200,
	volume = 0.4,
	skill = "kinetic", -- Skill awarded for this turret
	SLUG_SPEED = 2000,  -- Very fast but within CCD detection range
	SLUG_LENGTH = 16,
	SLUG_THICKNESS = 0.8,
	-- Make slug bright white for visibility
	SLUG_COLOR = {1, 1, 1, 1},
	SLUG_LIFETIME = 8,
	TRAIL_EMIT_RATE = 90,
	TRAIL_MAX_PARTICLES = 40,
	TRAIL_PARTICLE_LIFE = 0.12,
	TRAIL_SPREAD = 0.06,
	TRAIL_SPEED_MULTIPLIER = 1.1,
	TRAIL_COLOR = {1.0, 1.0, 1.0},
	COOLDOWN = 3,
	DPS = 30,
	design = {
		shape = "custom",
		size = 18,
		color = {0.75, 0.85, 1, 1}
	},
	draw = function(self, x, y)
		local size = self.design.size
		love.graphics.setColor(0.18, 0.2, 0.24, 1)
		love.graphics.rectangle("fill", x - size * 0.35, y - size * 0.5, size * 0.7, size, size * 0.15, size * 0.15)

		-- Twin acceleration rails
		love.graphics.setColor(0.65, 0.75, 0.9, 1)
		love.graphics.rectangle("fill", x - size * 0.55, y - size * 0.18, size * 1.1, size * 0.1, size * 0.05, size * 0.05)
		love.graphics.rectangle("fill", x - size * 0.55, y + size * 0.08, size * 1.1, size * 0.1, size * 0.05, size * 0.05)

		-- Capacitor core glow
		love.graphics.setColor(0.85, 0.9, 1.0, 0.9)
		love.graphics.rectangle("fill", x - size * 0.28, y - size * 0.12, size * 0.56, size * 0.24, size * 0.08, size * 0.08)
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.rectangle("fill", x - size * 0.28, y - size * 0.05, size * 0.56, size * 0.1, size * 0.04, size * 0.04)
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
	local barrelOffset = ownerCollidable and (ownerCollidable.radius + Railgun.SLUG_LENGTH * 0.35 + 6) or 24
	local spawnX = startX + dirX * barrelOffset
	local spawnY = startY + dirY * barrelOffset

	local slugRotation = math.atan2(dirY, dirX)
	-- Create a long, narrow triangle pointing in +X local space
	local halfLength = Railgun.SLUG_LENGTH * 0.5
	local thickness = Railgun.SLUG_THICKNESS
	local slugVertices = {
		-- Tip at front
		{x = halfLength, y = 0},
		-- Rear right
		{x = -halfLength, y = thickness},
		-- Rear left
		{x = -halfLength, y = -thickness}
	}

	local slugId = ECS.createEntity()
	ECS.addComponent(slugId, "Position", Components.Position(spawnX, spawnY))
	ECS.addComponent(slugId, "Velocity", Components.Velocity(dirX * Railgun.SLUG_SPEED, dirY * Railgun.SLUG_SPEED))
	ECS.addComponent(slugId, "Physics", Components.Physics(1.0, 0.5, 0.99))  -- Required for physics collisions
	ECS.addComponent(slugId, "PolygonShape", Components.PolygonShape(slugVertices, slugRotation))
	-- Use polygon renderable with explicit white color - projectiles will get special rendering without thick outlines
	ECS.addComponent(slugId, "Renderable", Components.Renderable("polygon", nil, nil, nil, Railgun.SLUG_COLOR))
	-- Collidable radius is very small for the tiny railgun slug
	ECS.addComponent(slugId, "Collidable", Components.Collidable(Railgun.SLUG_THICKNESS * 1.5))
	ECS.addComponent(slugId, "Durability", Components.Durability(1, 1))  -- Required for brittle projectiles to be destroyed
	-- Apply damage multiplier from owner ship
	local damageMultiplier = 1.0
	local ownerDamageMultiplier = ECS.getComponent(ownerId, "DamageMultiplier")
	if ownerDamageMultiplier then
		damageMultiplier = ownerDamageMultiplier.multiplier
	end
	
	ECS.addComponent(slugId, "Projectile", {ownerId = ownerId, damage = Railgun.DPS * damageMultiplier, brittle = true, isMissile = false, weaponModule = Railgun.name})
	ECS.addComponent(slugId, "ProjectileLifetime", {age = 0, maxAge = Railgun.SLUG_LIFETIME})
	ECS.addComponent(slugId, "ShatterEffect", {
		numPieces = 4,
		color = Railgun.SLUG_COLOR
	})
	ECS.addComponent(slugId, "TrailEmitter", Components.TrailEmitter(
		Railgun.TRAIL_EMIT_RATE,
		Railgun.TRAIL_MAX_PARTICLES,
		Railgun.TRAIL_PARTICLE_LIFE,
		Railgun.TRAIL_SPREAD,
		Railgun.TRAIL_SPEED_MULTIPLIER,
		Railgun.TRAIL_COLOR
	))
end

return Railgun
