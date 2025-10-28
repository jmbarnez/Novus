-- tests/ecs_core_test.lua
-- Basic ECS core tests: entity creation, component add/remove, system order

local ECS = require('src.ecs')
-- Ensure a clean ECS state for deterministic tests
ECS.clear()

local function assertEqual(a, b, msg)
    if a ~= b then error(msg or (tostring(a) .. ' ~= ' .. tostring(b))) end
end

-- Test entity creation
do
    local id1 = ECS.createEntity()
    local id2 = ECS.createEntity()
    assert(id1 ~= id2, 'Entities should have unique IDs')
    assert(ECS.getComponent(id1, 'TestComponent') == nil, 'New entity should have no components')
end

-- Test component add/remove
do
    local id = ECS.createEntity()
    ECS.addComponent(id, 'TestComponent', {foo = 42})
    local comp = ECS.getComponent(id, 'TestComponent')
    assert(comp and comp.foo == 42, 'Component add/get failed')
    ECS.removeComponent(id, 'TestComponent')
    assert(ECS.getComponent(id, 'TestComponent') == nil, 'Component remove failed')
end

-- Test system order by priority
do
    local calls = {}
    local SysA = {name = 'SysA', priority = 2, update = function() table.insert(calls, 'A') end}
    local SysB = {name = 'SysB', priority = 1, update = function() table.insert(calls, 'B') end}
    ECS.registerSystem('SysA', SysA)
    ECS.registerSystem('SysB', SysB)
    ECS.update(0)
    assertEqual(calls[1], 'B', 'System with lower priority should run first')
    assertEqual(calls[2], 'A', 'System with higher priority should run second')
end

print('ECS core tests passed!')

-- Clean up after test
ECS.clear()
