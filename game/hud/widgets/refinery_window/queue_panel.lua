--- Refinery Window Queue Panel
--- Draws the smelting queue on the right side

local RefineryQueue = require("game.systems.refinery_queue")
local RefineryBaySystem = require("ecs.systems.refinery_bay_system")
local Items = require("game.items")
local Helpers = require("game.hud.widgets.refinery_window.helpers")

local QueuePanel = {}

local pointInRect = Helpers.pointInRect
local SLOT_H = Helpers.SLOT_H
local PAD = Helpers.PAD

--- Draw the queue panel
--- @param ctx table Context
--- @param rect table Panel bounds {x, y, w, h}
--- @param state table Widget state (fonts)
function QueuePanel.draw(ctx, rect, state)
    local station = Helpers.getStation(ctx)
    local jobs = RefineryQueue.getJobs(station)
    local maxSlots = station and station.refinery_queue and station.refinery_queue.maxSlots or 3

    -- Panel header
    love.graphics.setFont(state.fonts.status)
    love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
    love.graphics.print(string.format("QUEUE (%d/%d)", #jobs, maxSlots), rect.x, rect.y - 20)

    -- Divider line on left
    love.graphics.setColor(0.5, 0.4, 0.3, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(rect.x - 8, rect.y, rect.x - 8, rect.y + rect.h)

    local slotH = SLOT_H
    local pad = PAD
    local yOffset = 0

    -- Bay processing section (if station has a bay)
    if station and station.refinery_bay then
        local bayStatus = RefineryBaySystem.getBayStatus(station)
        if bayStatus and bayStatus.processing then
            local baySlotH = slotH
            local sy = rect.y + yOffset
            local slotRect = { x = rect.x, y = sy, w = rect.w, h = baySlotH - pad * 2 }
            local mx, my = love.mouse.getPosition()

            QueuePanel.drawBaySlot(ctx, slotRect, state, bayStatus, mx, my)
            yOffset = yOffset + baySlotH
        end
    end

    -- Regular queue slots
    for i = 1, maxSlots do
        local job = jobs[i]
        local sy = rect.y + yOffset + (i - 1) * slotH + pad
        local slotRect = { x = rect.x, y = sy, w = rect.w, h = slotH - pad * 2 }
        local mx, my = love.mouse.getPosition()

        if job then
            QueuePanel.drawActiveSlot(ctx, slotRect, state, job, mx, my)
        else
            QueuePanel.drawEmptySlot(ctx, slotRect, state)
        end
    end
end

--- Draw an active job slot
function QueuePanel.drawActiveSlot(ctx, slotRect, state, job, mx, my)
    local progress = RefineryQueue.getJobProgress(job)
    local isComplete = RefineryQueue.isJobComplete(job)
    local timeRemaining = RefineryQueue.getTimeRemaining(job)

    -- Background
    love.graphics.setColor(0.15, 0.12, 0.10, 0.9)
    love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)

    -- Progress bar background
    local barY = slotRect.y + slotRect.h - 20
    local barH = 14
    love.graphics.setColor(0.1, 0.08, 0.06, 0.9)
    love.graphics.rectangle("fill", slotRect.x + 4, barY, slotRect.w - 8, barH, 3)

    -- Progress bar fill
    if isComplete then
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(0.3 * pulse, 0.8 * pulse, 0.3 * pulse, 0.9)
    else
        love.graphics.setColor(0.9, 0.55, 0.15, 0.9)
    end
    love.graphics.rectangle("fill", slotRect.x + 4, barY, (slotRect.w - 8) * progress, barH, 3)

    -- Progress bar border
    love.graphics.setColor(0.6, 0.45, 0.25, 0.8)
    love.graphics.rectangle("line", slotRect.x + 4, barY, slotRect.w - 8, barH, 3)

    -- Progress text
    love.graphics.setColor(1, 1, 1, 0.95)
    local progressText
    if isComplete then
        progressText = "READY!"
    else
        progressText = string.format("%d%% - %s", math.floor(progress * 100), Helpers.formatTime(timeRemaining))
    end
    love.graphics.print(progressText, slotRect.x + 8, barY + 1)

    -- Job info
    love.graphics.setFont(state.fonts.label)
    local outputDef = Items.get(job.recipeOutputId)
    local outputName = outputDef and outputDef.name or job.recipeOutputId
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(string.format("%dx %s", job.quantity, outputName), slotRect.x + 8, slotRect.y + 6)

    -- Collect button (if complete)
    if isComplete then
        love.graphics.setFont(state.fonts.label)
        local collectBtnRect = { x = slotRect.x + slotRect.w - 60, y = slotRect.y + 4, w = 54, h = 22 }
        local collectHover = pointInRect(mx, my, collectBtnRect)

        love.graphics.setColor(0.25, 0.55, 0.25, collectHover and 1.0 or 0.8)
        love.graphics.rectangle("fill", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 3)
        love.graphics.setColor(0.4, 0.8, 0.4, 0.9)
        love.graphics.rectangle("line", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 3)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print("Collect", collectBtnRect.x + 4, collectBtnRect.y + 4)
    end

    -- Slot border
    love.graphics.setColor(0.6, 0.45, 0.25, 0.7)
    love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
end

--- Draw an empty slot
function QueuePanel.drawEmptySlot(ctx, slotRect, state)
    love.graphics.setColor(0.12, 0.10, 0.08, 0.5)
    love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
    love.graphics.setColor(0.4, 0.35, 0.25, 0.4)
    love.graphics.setLineStyle("rough")
    love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
    love.graphics.setLineStyle("smooth")

    love.graphics.setColor(0.5, 0.45, 0.35, 0.4)
    love.graphics.print("Empty Slot", slotRect.x + slotRect.w / 2 - 30, slotRect.y + slotRect.h / 2 - 8)
end

--- Draw the asteroid bay processing slot
function QueuePanel.drawBaySlot(ctx, slotRect, state, bayStatus, mx, my)
    local progress = bayStatus.progress or 0
    local isComplete = bayStatus.complete

    -- Background with distinct bay color (darker, more industrial)
    love.graphics.setColor(0.12, 0.10, 0.08, 0.95)
    love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)

    -- Bay label
    love.graphics.setFont(state.fonts.status)
    love.graphics.setColor(0.7, 0.5, 0.3, 0.9)
    love.graphics.print("ASTEROID BAY", slotRect.x + 8, slotRect.y + 4)

    -- Progress bar background
    local barY = slotRect.y + slotRect.h - 22
    local barH = 16
    love.graphics.setColor(0.08, 0.06, 0.05, 0.95)
    love.graphics.rectangle("fill", slotRect.x + 4, barY, slotRect.w - 8, barH, 3)

    -- Progress bar fill
    if isComplete then
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(0.2 * pulse, 0.85 * pulse, 0.3 * pulse, 0.95)
    else
        -- Orange to green gradient based on progress
        local r = 0.9 - progress * 0.7
        local g = 0.4 + progress * 0.5
        love.graphics.setColor(r, g, 0.1, 0.95)
    end
    love.graphics.rectangle("fill", slotRect.x + 4, barY, (slotRect.w - 8) * progress, barH, 3)

    -- Progress bar border
    love.graphics.setColor(0.5, 0.4, 0.25, 0.8)
    love.graphics.rectangle("line", slotRect.x + 4, barY, slotRect.w - 8, barH, 3)

    -- Progress text
    love.graphics.setColor(1, 1, 1, 0.95)
    local progressText
    if isComplete then
        progressText = "READY TO COLLECT!"
    else
        progressText = string.format("%d%% - %s", math.floor(progress * 100), Helpers.formatTime(bayStatus.remainingTime))
    end
    love.graphics.print(progressText, slotRect.x + 8, barY + 2)

    -- Output info
    love.graphics.setFont(state.fonts.label)
    local outputDef = Items.get(bayStatus.outputId)
    local outputName = outputDef and outputDef.name or bayStatus.outputId
    love.graphics.setColor(1, 0.9, 0.7, 0.95)
    love.graphics.print(string.format("%dx %s", bayStatus.quantity, outputName), slotRect.x + 8, slotRect.y + 22)

    -- Collect button (if complete)
    if isComplete then
        love.graphics.setFont(state.fonts.label)
        local collectBtnRect = { x = slotRect.x + slotRect.w - 65, y = slotRect.y + 18, w = 58, h = 24 }
        local collectHover = pointInRect(mx, my, collectBtnRect)

        love.graphics.setColor(0.2, 0.5, 0.2, collectHover and 1.0 or 0.85)
        love.graphics.rectangle("fill", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 3)
        love.graphics.setColor(0.35, 0.75, 0.35, 0.95)
        love.graphics.rectangle("line", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w, collectBtnRect.h, 3)
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.print("Collect", collectBtnRect.x + 6, collectBtnRect.y + 5)
    end

    -- Slot border (distinct bay style)
    love.graphics.setColor(0.7, 0.5, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
    love.graphics.setLineWidth(1)
end

return QueuePanel
