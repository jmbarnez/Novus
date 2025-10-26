---@diagnostic disable: undefined-global
-- NOVUS - Game State Management
-- Centralized game state management module to replace global Game object

local GameState = {}

-- Dependencies
local SaveLoad = require('src.save_load')

-- Reference to the main gameState variable (set by main.lua)
local currentGameState = "start"

-- Callbacks from main.lua (to avoid circular dependencies)
local callbacks = {}

-- Initialize callbacks (called by main.lua)
function GameState.initCallbacks(callbackTable)
    callbacks = callbackTable or {}
end

-- Game state management functions
function GameState.returnToMainMenu()
    if currentGameState == "game" then
        if callbacks.quit then
            callbacks.quit()
        end
        currentGameState = "start"
    end
end

function GameState.save(slotName)
    return SaveLoad.saveToFile(slotName)
end

function GameState.load(slotName)
    local snapshot, err = SaveLoad.loadFromFile(slotName)
    if not snapshot then
        return nil, err
    end

    if callbacks.loadSnapshot then
        local ok, loadErr = callbacks.loadSnapshot(snapshot)
        if ok then
            currentGameState = "game"
        end
        return ok, loadErr
    end

    return nil, "loadSnapshot callback not available"
end

function GameState.loadSnapshot(snapshot)
    if callbacks.loadSnapshot then
        local ok, err = callbacks.loadSnapshot(snapshot)
        if ok then
            currentGameState = "game"
        end
        return ok, err
    end

    return nil, "loadSnapshot callback not available"
end

-- Set the current game state (called by main.lua)
function GameState.setGameState(state)
    currentGameState = state
end

-- Get the current game state
function GameState.getGameState()
    return currentGameState
end

return GameState
