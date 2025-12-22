--- Refinery Window HUD Widget
--- Fullscreen window for ore processing with smelting queue

local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local Refinery = require("game.systems.refinery")
local RefineryUI = require("game.hud.refinery_state")
local RefineryQueue = require("game.systems.refinery_queue")
local ItemIcons = require("game.item_icons")
local Items = require("game.items")
local Inventory = require("game.inventory")

local pointInRect = Rect.pointInRect

local function makeRefineryWindow()
    local self = {
        windowFrame = WindowFrame.new(),
        scrollY = 0,
        quantities = {},    -- Per-recipe quantity inputs
        notification = nil, -- { text, isSuccess, timer }
    }

    -- Constants
    local WINDOW_W = 700
    local WINDOW_H = 450
    local HEADER_H = 32
    local CONTENT_PAD = 12
    local LEFT_PANEL_W = 380  -- Recipes panel
    local RIGHT_PANEL_W = 280 -- Queue panel

    -- Batch presets
    local BATCH_PRESETS = { 1, 5, 10 }

    -- State access
    local function getRefineryUI(ctx)
        local world = ctx and ctx.world
        return world and world:getResource("refinery_ui")
    end

    local function getStation(ctx)
        local refineryUi = getRefineryUI(ctx)
        return refineryUi and refineryUi.stationEntity
    end

    local function setOpen(ctx, open, stationEntity)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi then return end

        if open then
            RefineryUI.open(refineryUi, stationEntity)
            self.quantities = {}
            -- Bring window to front
            if ctx.hud then
                ctx.hud:bringToFront(self)
            end
        else
            RefineryUI.close(refineryUi)
        end
    end

    -- Layout computation
    local function computeLayout(ctx)
        local bounds = self.windowFrame:compute(ctx, WINDOW_W, WINDOW_H, {
            headerH = HEADER_H,
            closeSize = 18,
            closePad = 8,
        })

        -- Left panel (recipes)
        local contentY = bounds.y + HEADER_H + CONTENT_PAD
        local contentH = WINDOW_H - HEADER_H - CONTENT_PAD * 2
        bounds.leftPanel = {
            x = bounds.x + CONTENT_PAD,
            y = contentY,
            w = LEFT_PANEL_W - CONTENT_PAD,
            h = contentH
        }

        -- Right panel (queue)
        bounds.rightPanel = {
            x = bounds.x + LEFT_PANEL_W + CONTENT_PAD,
            y = contentY,
            w = RIGHT_PANEL_W - CONTENT_PAD * 2,
            h = contentH
        }

        return bounds
    end

    -- Get quantity for a recipe
    local function getQuantity(recipeInputId)
        return self.quantities[recipeInputId] or 1
    end

    -- Set quantity for a recipe
    local function setQuantity(recipeInputId, qty)
        qty = math.max(1, math.min(99, qty or 1))
        self.quantities[recipeInputId] = qty
    end

    -- Show notification
    local function showNotification(text, isSuccess)
        self.notification = {
            text = text,
            isSuccess = isSuccess,
            timer = 2.0,
        }
    end

    -- Calculate fee with batch bonuses
    local function calculateFee(recipe, quantity)
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

    -- Format time as MM:SS or SS
    local function formatTime(seconds)
        seconds = math.ceil(seconds)
        if seconds >= 60 then
            local mins = math.floor(seconds / 60)
            local secs = seconds % 60
            return string.format("%d:%02d", mins, secs)
        else
            return string.format("%ds", seconds)
        end
    end

    -- Draw recipe panel (left side)
    local function drawRecipePanel(ctx, rect)
        local recipes = Refinery.getRecipes()
        local recipeH = 85
        local pad = 6

        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship
        local station = getStation(ctx)
        local freeSlots = RefineryQueue.getFreeSlots(station)

        -- Panel header
        love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
        love.graphics.print("RECIPES", rect.x, rect.y - 20)

        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)

        if #recipes == 0 then
            love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
            love.graphics.print("No recipes available", rect.x + 10, rect.y + 10)
        else
            for i, recipe in ipairs(recipes) do
                local ry = rect.y + (i - 1) * recipeH + pad - self.scrollY

                if ry + recipeH > rect.y and ry < rect.y + rect.h then
                    local recipeRect = { x = rect.x, y = ry, w = rect.w, h = recipeH - pad }
                    local mx, my = love.mouse.getPosition()
                    local hovered = pointInRect(mx, my, recipeRect)

                    -- Background
                    love.graphics.setColor(0.18, 0.14, 0.10, hovered and 0.95 or 0.75)
                    love.graphics.rectangle("fill", recipeRect.x, recipeRect.y, recipeRect.w, recipeRect.h, 4)

                    -- Border
                    love.graphics.setColor(0.70, 0.50, 0.30, hovered and 0.9 or 0.5)
                    love.graphics.setLineWidth(hovered and 2 or 1)
                    love.graphics.rectangle("line", recipeRect.x, recipeRect.y, recipeRect.w, recipeRect.h, 4)

                    -- Input/Output icons and arrow
                    local iconSize = 28
                    local iconX = recipeRect.x + 8
                    local iconY = recipeRect.y + 8
                    ItemIcons.draw(recipe.inputId, iconX, iconY, iconSize, iconSize)

                    -- Arrow
                    local arrowX = iconX + iconSize + 8
                    local arrowY = iconY + iconSize / 2
                    love.graphics.setColor(0.85, 0.65, 0.35, 0.95)
                    love.graphics.polygon("fill",
                        arrowX, arrowY - 5,
                        arrowX + 10, arrowY,
                        arrowX, arrowY + 5
                    )

                    -- Output icon
                    local outIconX = arrowX + 14
                    ItemIcons.draw(recipe.outputId, outIconX, iconY, iconSize, iconSize)

                    -- Recipe text
                    local textX = outIconX + iconSize + 10
                    love.graphics.setColor(1, 1, 1, 0.95)
                    local ratioText = string.format("%d %s → 1 %s", recipe.ratio, recipe.inputName, recipe.outputName)
                    love.graphics.print(ratioText, textX, recipeRect.y + 8)

                    -- Time per unit
                    love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
                    local timeText = string.format("Time: %s each", formatTime(recipe.timePerUnit))
                    love.graphics.print(timeText, textX, recipeRect.y + 24)

                    -- Available ore count
                    local oreCount = ship and Refinery.getPlayerOreCount(ship, recipe.inputId) or 0
                    love.graphics.setColor(0.6, 0.8, 0.6, 0.8)
                    local stockText = string.format("Have: %d ore", oreCount)
                    love.graphics.print(stockText, textX, recipeRect.y + 40)

                    -- Quantity controls row
                    local qty = getQuantity(recipe.inputId)
                    local controlY = recipeRect.y + recipeRect.h - 26
                    local controlX = recipeRect.x + 8

                    -- Batch preset buttons
                    for j, preset in ipairs(BATCH_PRESETS) do
                        local btnW = 24
                        local btnRect = { x = controlX + (j - 1) * (btnW + 4), y = controlY, w = btnW, h = 20 }
                        local btnHover = pointInRect(mx, my, btnRect)
                        local isActive = qty == preset

                        love.graphics.setColor(isActive and 0.50 or 0.25, isActive and 0.35 or 0.20,
                            isActive and 0.15 or 0.12, btnHover and 1.0 or 0.8)
                        love.graphics.rectangle("fill", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
                        love.graphics.setColor(0.70, 0.55, 0.35, isActive and 1.0 or 0.6)
                        love.graphics.rectangle("line", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
                        love.graphics.setColor(1, 1, 1, isActive and 1.0 or 0.7)
                        love.graphics.print(tostring(preset), btnRect.x + 7, btnRect.y + 3)
                    end

                    -- "Max" button
                    local maxQty = math.floor(oreCount / recipe.ratio)
                    local maxBtnX = controlX + #BATCH_PRESETS * 28
                    local maxBtnRect = { x = maxBtnX, y = controlY, w = 32, h = 20 }
                    local maxHover = pointInRect(mx, my, maxBtnRect)
                    love.graphics.setColor(0.25, 0.20, 0.12, maxHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", maxBtnRect.x, maxBtnRect.y, maxBtnRect.w, maxBtnRect.h, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.6)
                    love.graphics.rectangle("line", maxBtnRect.x, maxBtnRect.y, maxBtnRect.w, maxBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.7)
                    love.graphics.print("Max", maxBtnRect.x + 4, maxBtnRect.y + 3)

                    -- Quantity display
                    local qtyDispX = maxBtnX + 40
                    love.graphics.setColor(0.14, 0.12, 0.08, 0.9)
                    love.graphics.rectangle("fill", qtyDispX, controlY, 28, 20, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
                    love.graphics.rectangle("line", qtyDispX, controlY, 28, 20, 3)
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.print(tostring(qty), qtyDispX + 8, controlY + 3)

                    -- +/- buttons
                    local minusBtnRect = { x = qtyDispX + 32, y = controlY, w = 20, h = 20 }
                    local minusHover = pointInRect(mx, my, minusBtnRect)
                    love.graphics.setColor(0.25, 0.20, 0.15, minusHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
                    love.graphics.rectangle("line", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.print("-", minusBtnRect.x + 6, minusBtnRect.y + 2)

                    local plusBtnRect = { x = qtyDispX + 56, y = controlY, w = 20, h = 20 }
                    local plusHover = pointInRect(mx, my, plusBtnRect)
                    love.graphics.setColor(0.25, 0.20, 0.15, plusHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
                    love.graphics.rectangle("line", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.print("+", plusBtnRect.x + 5, plusBtnRect.y + 2)

                    -- Start button
                    local requiredOre = qty * recipe.ratio
                    local fee = calculateFee(recipe, qty)
                    local playerCredits = (player and player.credits and player.credits.balance) or 0
                    local canStart = oreCount >= requiredOre and playerCredits >= fee and freeSlots > 0

                    local startBtnRect = { x = qtyDispX + 84, y = controlY, w = 60, h = 20 }
                    local startHover = pointInRect(mx, my, startBtnRect) and canStart

                    if canStart then
                        love.graphics.setColor(0.50, 0.35, 0.15, startHover and 1.0 or 0.8)
                        love.graphics.rectangle("fill", startBtnRect.x, startBtnRect.y, startBtnRect.w, startBtnRect.h, 3)
                        love.graphics.setColor(0.90, 0.65, 0.30, 0.9)
                        love.graphics.rectangle("line", startBtnRect.x, startBtnRect.y, startBtnRect.w, startBtnRect.h, 3)
                        love.graphics.setColor(1, 1, 1, 0.95)
                    else
                        love.graphics.setColor(0.20, 0.18, 0.15, 0.5)
                        love.graphics.rectangle("fill", startBtnRect.x, startBtnRect.y, startBtnRect.w, startBtnRect.h, 3)
                        love.graphics.setColor(0.40, 0.35, 0.30, 0.5)
                        love.graphics.rectangle("line", startBtnRect.x, startBtnRect.y, startBtnRect.w, startBtnRect.h, 3)
                        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                    end
                    love.graphics.print("Start", startBtnRect.x + 14, startBtnRect.y + 3)

                    -- Fee display
                    love.graphics.setColor(0.85, 0.80, 0.40, 0.9)
                    love.graphics.print(string.format("%d cr", fee), startBtnRect.x + startBtnRect.w + 8, controlY + 3)
                end
            end
        end

        love.graphics.setScissor()
        love.graphics.setLineWidth(1)
    end

    -- Draw queue panel (right side)
    local function drawQueuePanel(ctx, rect)
        local station = getStation(ctx)
        local jobs = RefineryQueue.getJobs(station)
        local maxSlots = station and station.refinery_queue and station.refinery_queue.maxSlots or 3
        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship

        -- Panel header
        love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
        love.graphics.print(string.format("QUEUE (%d/%d)", #jobs, maxSlots), rect.x, rect.y - 20)

        -- Divider line on left
        love.graphics.setColor(0.5, 0.4, 0.3, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(rect.x - 8, rect.y, rect.x - 8, rect.y + rect.h)

        local slotH = 70
        local pad = 6

        for i = 1, maxSlots do
            local job = jobs[i]
            local sy = rect.y + (i - 1) * slotH + pad
            local slotRect = { x = rect.x, y = sy, w = rect.w, h = slotH - pad * 2 }
            local mx, my = love.mouse.getPosition()

            if job then
                -- Active job slot
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
                    -- Pulsing green for complete
                    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
                    love.graphics.setColor(0.3 * pulse, 0.8 * pulse, 0.3 * pulse, 0.9)
                else
                    -- Orange gradient for in-progress
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
                    progressText = string.format("%d%% - %s", math.floor(progress * 100), formatTime(timeRemaining))
                end
                love.graphics.print(progressText, slotRect.x + 8, barY + 1)

                -- Job info
                local outputDef = Items.get(job.recipeOutputId)
                local outputName = outputDef and outputDef.name or job.recipeOutputId
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print(string.format("%dx %s", job.quantity, outputName), slotRect.x + 8, slotRect.y + 6)

                -- Collect button (if complete)
                if isComplete then
                    local collectBtnRect = { x = slotRect.x + slotRect.w - 60, y = slotRect.y + 4, w = 54, h = 22 }
                    local collectHover = pointInRect(mx, my, collectBtnRect)

                    love.graphics.setColor(0.25, 0.55, 0.25, collectHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w,
                        collectBtnRect.h, 3)
                    love.graphics.setColor(0.4, 0.8, 0.4, 0.9)
                    love.graphics.rectangle("line", collectBtnRect.x, collectBtnRect.y, collectBtnRect.w,
                        collectBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.print("Collect", collectBtnRect.x + 4, collectBtnRect.y + 4)
                end

                -- Slot border
                love.graphics.setColor(0.6, 0.45, 0.25, 0.7)
                love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
            else
                -- Empty slot
                love.graphics.setColor(0.12, 0.10, 0.08, 0.5)
                love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
                love.graphics.setColor(0.4, 0.35, 0.25, 0.4)
                love.graphics.setLineStyle("rough")
                love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h, 4)
                love.graphics.setLineStyle("smooth")

                love.graphics.setColor(0.5, 0.45, 0.35, 0.4)
                love.graphics.print("Empty Slot", slotRect.x + slotRect.w / 2 - 30, slotRect.y + slotRect.h / 2 - 8)
            end
        end
    end

    -- Interface: hitTest
    function self.hitTest(ctx, x, y)
        local refineryUi = getRefineryUI(ctx)
        return refineryUi and refineryUi.open or false
    end

    -- Interface: draw
    function self.draw(ctx)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return end

        local bounds = computeLayout(ctx)

        -- Window frame
        self.windowFrame:draw(ctx, bounds, {
            title = "REFINERY",
            headerAlpha = 0.55,
            headerLineAlpha = 0.4,
            owner = self,
        })

        -- Left panel (recipes)
        drawRecipePanel(ctx, bounds.leftPanel)

        -- Right panel (queue)
        drawQueuePanel(ctx, bounds.rightPanel)

        -- Draw notification
        if self.notification and self.notification.timer and self.notification.timer > 0 then
            local notif = self.notification
            local alpha = math.min(1, notif.timer / 0.5)
            local font = love.graphics.getFont()
            local text = notif.text
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local nx = bounds.x + (WINDOW_W - tw) / 2
            local ny = bounds.y + WINDOW_H - 40

            -- Background
            love.graphics.setColor(0.10, 0.08, 0.05, 0.9 * alpha)
            love.graphics.rectangle("fill", nx - 12, ny - 6, tw + 24, th + 12, 4)

            -- Border and text color
            if notif.isSuccess then
                love.graphics.setColor(0.90, 0.65, 0.30, 0.9 * alpha)
                love.graphics.rectangle("line", nx - 12, ny - 6, tw + 24, th + 12, 4)
                love.graphics.setColor(1.00, 0.80, 0.40, alpha)
            else
                love.graphics.setColor(0.80, 0.40, 0.30, 0.9 * alpha)
                love.graphics.rectangle("line", nx - 12, ny - 6, tw + 24, th + 12, 4)
                love.graphics.setColor(1.00, 0.50, 0.40, alpha)
            end
            love.graphics.print(text, nx, ny)

            notif.timer = notif.timer - (1 / 60)
            if notif.timer <= 0 then
                self.notification = nil
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Start a smelting job
    local function startSmeltingJob(ctx, recipe, quantity)
        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship
        local station = getStation(ctx)

        if not player or not ship or not station then
            showNotification("Cannot start job", false)
            return
        end

        -- Check ore
        local oreCount = Refinery.getPlayerOreCount(ship, recipe.inputId)
        local requiredOre = quantity * recipe.ratio
        if oreCount < requiredOre then
            showNotification("Not enough ore", false)
            return
        end

        -- Check credits
        local fee = calculateFee(recipe, quantity)
        if player.credits.balance < fee then
            showNotification("Not enough credits", false)
            return
        end

        -- Check queue slots
        if RefineryQueue.getFreeSlots(station) <= 0 then
            showNotification("Queue is full", false)
            return
        end

        -- Remove ore from cargo
        local inputDef = Items.get(recipe.inputId)
        local inputUnitVolume = (inputDef and inputDef.unitVolume) or 1
        local oreVolumeToRemove = requiredOre * inputUnitVolume

        local oreToRemove = oreVolumeToRemove
        for _, slot in ipairs(ship.cargo_hold.slots) do
            if slot.id == recipe.inputId and slot.volume and slot.volume > 0 then
                local take = math.min(slot.volume, oreToRemove)
                slot.volume = slot.volume - take
                oreToRemove = oreToRemove - take
                if slot.volume <= 0 then
                    Inventory.clear(slot)
                end
                if oreToRemove <= 0 then break end
            end
        end

        -- Deduct fee
        player.credits.balance = player.credits.balance - fee

        -- Update cargo used
        ship.cargo.used = Inventory.totalVolume(ship.cargo_hold.slots)

        -- Start the job
        local success, msg = RefineryQueue.startJob(station, recipe, quantity, oreVolumeToRemove, fee)
        showNotification(success and "Smelting started!" or msg, success)
    end

    -- Interface: keypressed
    function self.keypressed(ctx, key)
        local refineryUi = getRefineryUI(ctx)

        -- Open refinery window on E when near refinery
        if key == "e" then
            if refineryUi and refineryUi.open then
                setOpen(ctx, false)
                return true
            elseif ctx.refineryPrompt and ctx.refineryPrompt.entity then
                setOpen(ctx, true, ctx.refineryPrompt.entity)
                return true
            end
        end

        if not refineryUi or not refineryUi.open then
            return false
        end

        if key == "escape" then
            setOpen(ctx, false)
            return true
        end

        return false
    end

    -- Interface: mousepressed
    function self.mousepressed(ctx, x, y, button)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        local bounds = computeLayout(ctx)

        -- Bring to front when clicked
        if pointInRect(x, y, bounds) and ctx.hud then
            ctx.hud:bringToFront(self)
        end

        -- Window frame (close button, drag header)
        local consumed, closeHit, headerDrag = self.windowFrame:mousepressed(ctx, bounds, x, y, button)
        if closeHit then
            setOpen(ctx, false)
            return true
        end
        if headerDrag then
            return true
        end

        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship
        local station = getStation(ctx)

        -- Recipe panel clicks
        if button == 1 and pointInRect(x, y, bounds.leftPanel) then
            local recipes = Refinery.getRecipes()
            local recipeH = 85
            local pad = 6

            for i, recipe in ipairs(recipes) do
                local ry = bounds.leftPanel.y + (i - 1) * recipeH + pad - self.scrollY
                local recipeRect = { x = bounds.leftPanel.x, y = ry, w = bounds.leftPanel.w, h = recipeH - pad }

                if ry + recipeH > bounds.leftPanel.y and ry < bounds.leftPanel.y + bounds.leftPanel.h then
                    local controlY = ry + recipeH - pad - 26
                    local controlX = bounds.leftPanel.x + 8

                    -- Batch preset buttons
                    for j, preset in ipairs(BATCH_PRESETS) do
                        local btnW = 24
                        local btnRect = { x = controlX + (j - 1) * (btnW + 4), y = controlY, w = btnW, h = 20 }
                        if pointInRect(x, y, btnRect) then
                            setQuantity(recipe.inputId, preset)
                            return true
                        end
                    end

                    -- Max button
                    local oreCount = ship and Refinery.getPlayerOreCount(ship, recipe.inputId) or 0
                    local maxQty = math.max(1, math.floor(oreCount / recipe.ratio))
                    local maxBtnX = controlX + #BATCH_PRESETS * 28
                    if pointInRect(x, y, { x = maxBtnX, y = controlY, w = 32, h = 20 }) then
                        setQuantity(recipe.inputId, maxQty)
                        return true
                    end

                    -- Minus button
                    local qtyDispX = maxBtnX + 40
                    if pointInRect(x, y, { x = qtyDispX + 32, y = controlY, w = 20, h = 20 }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) - 1)
                        return true
                    end

                    -- Plus button
                    if pointInRect(x, y, { x = qtyDispX + 56, y = controlY, w = 20, h = 20 }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) + 1)
                        return true
                    end

                    -- Start button
                    if pointInRect(x, y, { x = qtyDispX + 84, y = controlY, w = 60, h = 20 }) then
                        local qty = getQuantity(recipe.inputId)
                        startSmeltingJob(ctx, recipe, qty)
                        return true
                    end
                end
            end
        end

        -- Queue panel clicks (collect button)
        if button == 1 and pointInRect(x, y, bounds.rightPanel) then
            local jobs = RefineryQueue.getJobs(station)
            local maxSlots = station and station.refinery_queue and station.refinery_queue.maxSlots or 3
            local slotH = 70
            local pad = 6

            for i = 1, maxSlots do
                local job = jobs[i]
                if job and RefineryQueue.isJobComplete(job) then
                    local sy = bounds.rightPanel.y + (i - 1) * slotH + pad
                    local collectBtnRect = {
                        x = bounds.rightPanel.x + bounds.rightPanel.w - 60,
                        y = sy + 4,
                        w = 54,
                        h = 22
                    }

                    if pointInRect(x, y, collectBtnRect) then
                        local success, msg = RefineryQueue.collectJob(station, i, ship)
                        showNotification(msg, success)
                        return true
                    end
                end
            end
        end

        return pointInRect(x, y, bounds)
    end

    -- Interface: mousereleased
    function self.mousereleased(ctx, x, y, button)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        if self.windowFrame:mousereleased(ctx, x, y, button) then
            return true
        end

        return false
    end

    -- Interface: mousemoved
    function self.mousemoved(ctx, x, y, dx, dy)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        if self.windowFrame:mousemoved(ctx, x, y, dx, dy) then
            return true
        end

        return false
    end

    -- Interface: wheelmoved
    function self.wheelmoved(ctx, x, y)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        self.scrollY = math.max(0, self.scrollY - y * 30)
        return true
    end

    return self
end

return makeRefineryWindow()
