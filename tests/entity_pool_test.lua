local ECS = require('src.ecs')
local EntityPool = require('src.entity_pool')

-- Ensure a clean slate for the test
ECS.clear()
EntityPool.pools = {}

local function dummyFactory()
    local id = ECS.createEntity()
    ECS.addComponent(id, 'TestComponent', { value = true })
    return id
end

local function dummyReset(entityId)
    -- Remove the test component so the entity can be reused without stale data
    if ECS.getComponent(entityId, 'TestComponent') then
        ECS.removeComponent(entityId, 'TestComponent')
    end
end

EntityPool.registerPool('dummy', dummyFactory, dummyReset, 5)

local entityId = EntityPool.acquire('dummy')
assert(#EntityPool.pools['dummy'].available == 0, 'Entity should start in use')

local firstRelease = EntityPool.release('dummy', entityId)
assert(firstRelease == true, 'First release should succeed')
assert(#EntityPool.pools['dummy'].available == 1, 'Entity should be returned to available list')

local secondRelease = EntityPool.release('dummy', entityId)
assert(secondRelease == false, 'Second release should be ignored')
assert(#EntityPool.pools['dummy'].available == 1, 'Available list should not gain duplicates')

print('Entity pool release test passed')
