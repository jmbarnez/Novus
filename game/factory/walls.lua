local walls = {}

function walls.createWalls(physicsWorld, w, h)
  local margin = 0

  local body = love.physics.newBody(physicsWorld, 0, 0, "static")
  local shape = love.physics.newChainShape(true,
    margin, margin,
    w - margin, margin,
    w - margin, h - margin,
    margin, h - margin
  )

  local fixture = love.physics.newFixture(body, shape)
  fixture:setRestitution(1.0)
  fixture:setFriction(0.0)

  return body
end

return walls
