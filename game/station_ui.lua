--- Station UI State Manager
--- Tracks station window open/close state, active tab, and quests

local StationUI = {}

function StationUI.new()
    return {
        open = false,
        activeTab = "shop", -- "shop" or "quests"
        stationEntity = nil,
        quests = {},
    }
end

function StationUI.open(state, stationEntity, quests)
    state.open = true
    state.stationEntity = stationEntity
    state.quests = quests or {}
    state.activeTab = "shop"
end

function StationUI.close(state)
    state.open = false
    state.stationEntity = nil
end

function StationUI.setTab(state, tab)
    if tab == "shop" or tab == "quests" then
        state.activeTab = tab
    end
end

function StationUI.isOpen(state)
    return state and state.open or false
end

return StationUI
