local M = {}

local Items = require("game.items")

--- Spawn a pickup entity at the given world coordinates
---@param world table Concord world
---@param physicsWorld table Box2D physics world
---@param id string Item ID
---@param x number World X position
---@param y number World Y position
---@param volume number Item volume
---@param velocityX number|nil Optional initial X velocity
---@param velocityY number|nil Optional initial Y velocity
---@return table|nil The created entity, or nil on failure
function M.spawn(world, physicsWorld, id, x, y, volume, velocityX, velocityY)
    if not world or not physicsWorld then
        return nil
    end

    local def = Items.get(id)
    local color = (def and def.color) or { 0.7, 0.7, 0.7, 0.95 }

    local body = love.physics.newBody(physicsWorld, x, y, "dynamic")
    body:setLinearDamping(3.5)
    body:setAngularDamping(6.0)

    local shape = love.physics.newCircleShape(6)
    local fixture = love.physics.newFixture(body, shape, 0.2)
    fixture:setSensor(true)
    fixture:setCategory(16)
    fixture:setMask(1, 2, 4, 8, 16)

    if velocityX or velocityY then
        body:setLinearVelocity(velocityX or 0, velocityY or 0)
    end

    local e = world:newEntity()
        :give("physics_body", body, shape, fixture)
        :give("renderable", "pickup", color)
        :give("pickup", id, volume)

    fixture:setUserData(e)
    return e
end

return M
