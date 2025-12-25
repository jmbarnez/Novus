--- Refinery Window Bay Panel
--- Shows asteroid bay processing status and allows collection of finished items

local Items = require("game.items")
local Helpers = require("game.hud.widgets.refinery_window.helpers")
local RefineryBaySystem = require("ecs.systems.refinery_bay_system")

local BayPanel = {}

local pointInRect = Helpers.pointInRect
local PAD = Helpers.PAD

--- Draw the bay panel
--- @param ctx table Context
--- @param rect table Panel bounds {x, y, w, h}
--- @param state table Widget state (fonts, etc)
function BayPanel.draw(ctx, rect, state)
    local station = Helpers.getStation(ctx)
    if not station or not station.refinery_bay then
        return
    end

    local bay = station.refinery_bay
    local job = bay.processingJob
    local mx, my = love.mouse.getPosition()

    -- Panel header
    love.graphics.setFont(state.fonts.status)
    love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
    love.graphics.print("ASTEROID BAY", rect.x, rect.y)

    -- Bay info area
    local infoY = rect.y + 24
    local infoH = rect.h - 24

    -- Background
    love.graphics.setColor(0.12, 0.10, 0.08, 0.8)
    love.graphics.rectangle("fill", rect.x, infoY, rect.w, infoH, 4)
    love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
    love.graphics.rectangle("line", rect.x, infoY, rect.w, infoH, 4)

    if job then
        -- Processing job info
        local progress = math.min(1, job.progress / job.totalTime)
        local isComplete = job.progress >= job.totalTime
        local timeRemaining = math.max(0, job.totalTime - job.progress)

        -- Output item name
        local outputDef = Items.get(job.outputId)
        local outputName = outputDef and outputDef.name or job.outputId

        love.graphics.setFont(state.fonts.label)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(string.format("%dx %s", job.quantity, outputName), rect.x + PAD, infoY + PAD)

        -- Source label
        love.graphics.setColor(0.7, 0.6, 0.5, 0.7)
        love.graphics.print("From asteroid ore", rect.x + PAD, infoY + PAD + 18)

        -- Progress bar
        local barY = infoY + 50
        local barH = 16
        local barW = rect.w - PAD * 2

        -- Bar background
        love.graphics.setColor(0.1, 0.08, 0.06, 0.9)
        love.graphics.rectangle("fill", rect.x + PAD, barY, barW, barH, 3)

        -- Bar fill
        if isComplete then
            local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
            love.graphics.setColor(0.3 * pulse, 0.8 * pulse, 0.3 * pulse, 0.9)
        else
            -- Orange to green transition
            local r = 0.9 - progress * 0.7
            local g = 0.4 + progress * 0.5
            love.graphics.setColor(r, g, 0.1, 0.9)
        end
        love.graphics.rectangle("fill", rect.x + PAD, barY, barW * progress, barH, 3)

        -- Bar border
        love.graphics.setColor(0.6, 0.45, 0.25, 0.8)
        love.graphics.rectangle("line", rect.x + PAD, barY, barW, barH, 3)

        -- Progress text
        love.graphics.setColor(1, 1, 1, 0.95)
        local progressText
        if isComplete then
            progressText = "READY TO COLLECT!"
        else
            progressText = string.format("%d%% - %s remaining", math.floor(progress * 100),
            Helpers.formatTime(timeRemaining))
        end
        love.graphics.print(progressText, rect.x + PAD, barY + barH + 4)

        -- Collect button (if complete)
        if isComplete then
            local btnW = rect.w - PAD * 2
            local btnH = 28
            local btnY = infoY + infoH - btnH - PAD
            local collectBtnRect = { x = rect.x + PAD, y = btnY, w = btnW, h = btnH }
            local collectHover = pointInRect(mx, my, collectBtnRect)

            love.graphics.setColor(0.25, 0.55, 0.25, collectHover and 1.0 or 0.8)
            love.graphics.rectangle("fill", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 4)
            love.graphics.setColor(0.4, 0.8, 0.4, 0.9)
            love.graphics.rectangle("line", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 4)

            love.graphics.setColor(1, 1, 1, 0.95)
            local btnText = "Collect Ingots"
            local textW = state.fonts.label:getWidth(btnText)
            love.graphics.print(btnText, collectBtnRect.x + collectBtnRect.w / 2 - textW / 2, collectBtnRect.y + 6)

            -- Store button rect for click handling
            state.bayCollectBtn = collectBtnRect
        else
            state.bayCollectBtn = nil
        end
    else
        -- No job - show idle state
        love.graphics.setFont(state.fonts.label)
        love.graphics.setColor(0.6, 0.55, 0.45, 0.7)

        local text1 = "Bay is idle"
        local text2 = "Push an asteroid into the"
        local text3 = "bay opening to process it"

        local textW1 = state.fonts.label:getWidth(text1)
        love.graphics.print(text1, rect.x + rect.w / 2 - textW1 / 2, infoY + infoH / 2 - 24)
        love.graphics.print(text2, rect.x + PAD, infoY + infoH / 2)
        love.graphics.print(text3, rect.x + PAD, infoY + infoH / 2 + 16)

        state.bayCollectBtn = nil
    end
end

--- Handle mouse click on bay panel
--- @return boolean True if click was handled
function BayPanel.handleClick(ctx, state, x, y, button)
    if button ~= 1 then return false end

    if state.bayCollectBtn and pointInRect(x, y, state.bayCollectBtn) then
        local station = Helpers.getStation(ctx)
        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship

        local success, msg = RefineryBaySystem.collectBayJob(station, ship)
        if success then
            state.showNotification(msg, true)
        else
            state.showNotification(msg, false)
        end
        return true
    end

    return false
end

return BayPanel
