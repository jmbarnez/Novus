local Station = require('src.world_objects.station')

local prefabs = {
    station = Station,
}

local WorldObjects = {}

function WorldObjects.getPrefab(name)
    return prefabs[name]
end

function WorldObjects.listPrefabs()
    local keys = {}
    for k, _ in pairs(prefabs) do table.insert(keys, k) end
    return keys
end

return WorldObjects


