local Components = {}

-- WarpGate component (broken by default)
Components.WarpGate = function(data)
    return {
        destination = data and data.destination or nil,
        active = data and (data.active ~= nil) and data.active or false, -- default: broken
    }
end

return Components
