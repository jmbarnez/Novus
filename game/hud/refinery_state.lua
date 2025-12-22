--- Refinery UI State Manager
--- Tracks refinery window open/close state

local RefineryUI = {}

function RefineryUI.new()
    return {
        open = false,
        stationEntity = nil,
    }
end

function RefineryUI.open(state, stationEntity)
    state.open = true
    state.stationEntity = stationEntity
end

function RefineryUI.close(state)
    state.open = false
    state.stationEntity = nil
end

function RefineryUI.isOpen(state)
    return state and state.open or false
end

return RefineryUI
