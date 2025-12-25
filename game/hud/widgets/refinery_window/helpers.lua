--- Refinery Window Helpers
--- Shared constants, colors, and utility functions

local Rect = require("util.rect")
local RefineryUI = require("game.hud.refinery_state")

local Helpers = {}

-- Layout constants
Helpers.WINDOW_W = 700
Helpers.WINDOW_H = 450
Helpers.HEADER_H = 32
Helpers.CONTENT_PAD = 12
Helpers.LEFT_PANEL_W = 380
Helpers.RIGHT_PANEL_W = 280

-- Control sizing
Helpers.CONTROL_BTN_W = 22
Helpers.CONTROL_INPUT_W = 44
Helpers.CONTROL_ALL_W = 34
Helpers.CONTROL_GAP = 6
Helpers.CONTROL_H = 22
Helpers.CONTROL_BOTTOM_PAD = 2
Helpers.CARET_BLINK = 0.55
Helpers.HOLD_DELAY = 0.35
Helpers.HOLD_RATE = 0.08

-- Recipe/slot heights
Helpers.RECIPE_H = 95
Helpers.WORK_ORDER_H = 92
Helpers.SLOT_H = 70
Helpers.PAD = 6

-- Status colors for work orders
Helpers.STATUS_COLORS = {
    active = { 0.45, 0.85, 1.00, 0.95 },
    progress = { 0.98, 0.65, 0.25, 0.95 },
    completed = { 0.98, 0.85, 0.45, 0.95 },
    turnedin = { 0.55, 0.65, 0.80, 0.85 },
}

-- Text colors
Helpers.TEXT_COLORS = {
    description = { 1.0, 0.97, 0.90, 0.95 },
    amount = { 0.75, 0.85, 1.0, 0.9 },
    reward = { 0.98, 0.86, 0.45, 0.95 },
    level = { 0.75, 0.78, 0.9, 0.85 },
}

-- Common utility
Helpers.pointInRect = Rect.pointInRect

-- Get refinery UI from context
function Helpers.getRefineryUI(ctx)
    local world = ctx and ctx.world
    return world and world:getResource("refinery_ui")
end

-- Get station entity from context
function Helpers.getStation(ctx)
    local refineryUi = Helpers.getRefineryUI(ctx)
    return refineryUi and refineryUi.stationEntity
end

-- Format time as MM:SS or SS
function Helpers.formatTime(seconds)
    seconds = math.ceil(seconds)
    if seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", mins, secs)
    else
        return string.format("%ds", seconds)
    end
end

-- Calculate fee with batch bonuses
function Helpers.calculateFee(recipe, quantity)
    local baseFee = quantity * recipe.processingFee
    if recipe.batchBonuses then
        for _, bonus in ipairs(recipe.batchBonuses) do
            if quantity >= bonus.minQty and bonus.feeMultiplier then
                baseFee = baseFee * bonus.feeMultiplier
            end
        end
    end
    return math.floor(baseFee)
end

return Helpers
