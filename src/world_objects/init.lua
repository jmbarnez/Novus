local Station = require('src.world_objects.station')
local Turret = require('src.world_objects.turret')

local prefabs = {
    station = Station,
    turret = Turret,
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


