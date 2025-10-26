---@diagnostic disable: undefined-global
-- Save/Load system built on top of the ECS serialization helpers
-- Provides snapshot capture/restoration and simple filesystem persistence

local ECS = require('src.ecs')
local TimeManager = require('src.time_manager')
local AsteroidClusters = require('src.systems.asteroid_clusters')
local WorldLoader = require('src.world_loader')

local SaveLoad = {}

local SAVE_DIR = 'saves'
local SAVE_EXT = '.lua'

local function isArray(tbl)
    local count = 0
    for k in pairs(tbl) do
        if type(k) ~= 'number' then
            return false
        end
        count = count + 1
    end
    for i = 1, count do
        if tbl[i] == nil then
            return false
        end
    end
    return true, count
end

local function serializeValue(value, indent, visited)
    local valueType = type(value)
    if valueType == 'number' then
        if value ~= value then
            return '0/0'
        end
        if value == math.huge then
            return 'math.huge'
        elseif value == -math.huge then
            return '-math.huge'
        end
        return tostring(value)
    elseif valueType == 'boolean' then
        return tostring(value)
    elseif valueType == 'string' then
        return string.format('%q', value)
    elseif valueType == 'nil' then
        return 'nil'
    elseif valueType ~= 'table' then
        error('Cannot serialize value of type ' .. valueType)
    end

    visited = visited or {}
    if visited[value] then
        error('Cannot serialize tables with cycles')
    end
    visited[value] = true

    local buffer = {'{'}
    local nextIndent = indent .. '  '
    local array, length = isArray(value)

    if array then
        for i = 1, length do
            table.insert(buffer, nextIndent .. serializeValue(value[i], nextIndent, visited) .. ',')
        end
    else
        local keys = {}
        for k in pairs(value) do
            table.insert(keys, k)
        end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta == tb then
                if ta == 'number' or ta == 'string' then
                    return a < b
                end
            end
            return tostring(a) < tostring(b)
        end)

        for _, key in ipairs(keys) do
            local keyStr
            if type(key) == 'string' and key:match('^[%a_][%w_]*$') then
                keyStr = key .. ' = '
            else
                keyStr = '[' .. serializeValue(key, nextIndent, visited) .. '] = '
            end
            local serialized = serializeValue(value[key], nextIndent, visited)
            table.insert(buffer, nextIndent .. keyStr .. serialized .. ',')
        end
    end

    table.insert(buffer, indent .. '}')
    visited[value] = nil
    return table.concat(buffer, '\n')
end

local function buildSavePath(slotName)
    slotName = slotName or 'slot1'
    return SAVE_DIR .. '/' .. slotName .. SAVE_EXT
end

function SaveLoad.captureSnapshot()
    local snapshot = {
        metadata = {
            version = 1,
            timestamp = os.time and os.time() or 0,
        },
        ecs = ECS.serialize(),
        timeManager = TimeManager.serialize and TimeManager.serialize() or nil,
        asteroidClusters = AsteroidClusters.serialize and AsteroidClusters.serialize() or nil,
        world = {
            id = WorldLoader.getCurrentWorldId()
        }
    }

    return snapshot
end

function SaveLoad.applySnapshot(snapshot)
    assert(type(snapshot) == 'table', 'Snapshot must be a table')
    assert(snapshot.ecs, 'Snapshot missing ECS data')

    AsteroidClusters.clear()
    ECS.deserialize(snapshot.ecs)

    if snapshot.asteroidClusters and AsteroidClusters.deserialize then
        AsteroidClusters.deserialize(snapshot.asteroidClusters)
    end

    if snapshot.timeManager and TimeManager.deserialize then
        TimeManager.deserialize(snapshot.timeManager)
    end

    if snapshot.world and snapshot.world.id then
        WorldLoader.setCurrentWorld(snapshot.world.id)
    else
        WorldLoader.setCurrentWorld(nil)
    end
end

function SaveLoad.snapshotToString(snapshot)
    local body = serializeValue(snapshot, '', {})
    return 'return ' .. body .. '\n'
end

function SaveLoad.saveToFile(slotName, snapshot)
    if not (love and love.filesystem) then
        return nil, 'love.filesystem is not available'
    end

    snapshot = snapshot or SaveLoad.captureSnapshot()
    local contents = SaveLoad.snapshotToString(snapshot)
    local path = buildSavePath(slotName)
    love.filesystem.createDirectory(SAVE_DIR)
    local success, err = love.filesystem.write(path, contents)
    if not success then
        return nil, err or 'failed to write save file'
    end
    return true
end

function SaveLoad.loadFromFile(slotName)
    if not (love and love.filesystem) then
        return nil, 'love.filesystem is not available'
    end

    local path = buildSavePath(slotName)
    if not love.filesystem.getInfo(path) then
        return nil, 'save not found'
    end

    local chunk, err = love.filesystem.load(path)
    if not chunk then
        return nil, err
    end

    local ok, data = pcall(chunk)
    if not ok then
        return nil, data
    end

    return data
end

return SaveLoad
