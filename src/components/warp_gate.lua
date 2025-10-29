local Components = {}

-- WarpGate component (broken by default)
Components.WarpGate = function(data)
    return {
        destination = data and data.destination or nil,
        active = data and (data.active ~= nil) and data.active or false, -- default: inactive (disabled by default)
        showRepairTooltip = true, -- Whether to show repair tooltip (default: true for broken gates)
    }
end

return Components
