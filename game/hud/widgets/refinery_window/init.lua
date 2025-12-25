--- Refinery Window HUD Widget
--- Main orchestrator that delegates to sub-modules

local WindowFrame = require("game.hud.window_frame")
local Refinery = require("game.systems.refinery")
local RefineryUI = require("game.hud.refinery_state")
local RefineryQueue = require("game.systems.refinery_queue")
local RefineryBaySystem = require("ecs.systems.refinery_bay_system")
local Items = require("game.items")
local Inventory = require("game.inventory")

local Helpers = require("game.hud.widgets.refinery_window.helpers")
local RecipePanel = require("game.hud.widgets.refinery_window.recipe_panel")
local QueuePanel = require("game.hud.widgets.refinery_window.queue_panel")

local pointInRect = Helpers.pointInRect
local WINDOW_W = Helpers.WINDOW_W
local WINDOW_H = Helpers.WINDOW_H
local HEADER_H = Helpers.HEADER_H
local CONTENT_PAD = Helpers.CONTENT_PAD
local LEFT_PANEL_W = Helpers.LEFT_PANEL_W
local RIGHT_PANEL_W = Helpers.RIGHT_PANEL_W
local CONTROL_BTN_W = Helpers.CONTROL_BTN_W
local CONTROL_INPUT_W = Helpers.CONTROL_INPUT_W
local CONTROL_ALL_W = Helpers.CONTROL_ALL_W
local CONTROL_GAP = Helpers.CONTROL_GAP
local CONTROL_H = Helpers.CONTROL_H
local CONTROL_BOTTOM_PAD = Helpers.CONTROL_BOTTOM_PAD
local CARET_BLINK = Helpers.CARET_BLINK
local HOLD_DELAY = Helpers.HOLD_DELAY
local HOLD_RATE = Helpers.HOLD_RATE
local RECIPE_H = Helpers.RECIPE_H
local WORK_ORDER_H = Helpers.WORK_ORDER_H
local PAD = Helpers.PAD

local function makeRefineryWindow()
    local self = {
        windowFrame = WindowFrame.new(),
        scrollY = 0,
        quantities = {},
        notification = nil,
        editingRecipeId = nil,
        editingText = "",
        caretTimer = 0,
        caretVisible = true,
        holdAction = nil,
        holdTimer = 0,
        holdRecipeId = nil,
        holdActionKey = nil,
    }

    self.fonts = {
        label = love.graphics.newFont("assets/fonts/Orbitron-SemiBold.ttf", 12),
        status = love.graphics.newFont("assets/fonts/Orbitron-Black.ttf", 14),
        reward = love.graphics.newFont("assets/fonts/Orbitron-Medium.ttf", 11),
        input = love.graphics.newFont("assets/fonts/Orbitron-SemiBold.ttf", 12),
    }

    local function getRefineryUI(ctx)
        return Helpers.getRefineryUI(ctx)
    end

    local function getStation(ctx)
        return Helpers.getStation(ctx)
    end

    local function setOpen(ctx, open, stationEntity)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi then return end

        if open then
            RefineryUI.open(refineryUi, stationEntity)
            self.quantities = {}
            self.editingRecipeId = nil
            self.editingText = ""
            self.holdAction = nil
            self.holdRecipeId = nil
            self.holdActionKey = nil
            self.holdTimer = 0
            if ctx.hud then
                ctx.hud:bringToFront(self)
            end
        else
            RefineryUI.close(refineryUi)
        end
    end

    local function computeLayout(ctx)
        local bounds = self.windowFrame:compute(ctx, WINDOW_W, WINDOW_H, {
            headerH = HEADER_H,
            closeSize = 18,
            closePad = 8,
        })

        local contentY = bounds.y + HEADER_H + CONTENT_PAD
        local contentH = WINDOW_H - HEADER_H - CONTENT_PAD * 2
        bounds.leftPanel = {
            x = bounds.x + CONTENT_PAD,
            y = contentY,
            w = LEFT_PANEL_W - CONTENT_PAD,
            h = contentH
        }

        bounds.rightPanel = {
            x = bounds.x + LEFT_PANEL_W + CONTENT_PAD,
            y = contentY,
            w = RIGHT_PANEL_W - CONTENT_PAD * 2,
            h = contentH
        }

        return bounds
    end

    local function getQuantity(recipeInputId)
        return self.quantities[recipeInputId] or 1
    end

    local function setQuantity(recipeInputId, qty)
        qty = math.max(1, math.min(99, tonumber(qty) or 1))
        self.quantities[recipeInputId] = qty
        if self.editingRecipeId == recipeInputId then
            self.editingText = tostring(qty)
        end
    end

    local function calculateFee(recipe, quantity)
        return Helpers.calculateFee(recipe, quantity)
    end

    local applyEditingText

    local function focusInput(recipeInputId)
        self.editingRecipeId = recipeInputId
        self.editingText = tostring(getQuantity(recipeInputId))
        self.caretTimer = 0
        self.caretVisible = true
        self.holdAction = nil
        self.holdTimer = 0
        self.holdRecipeId = nil
        self.holdActionKey = nil
    end

    local function blurInput()
        applyEditingText()
        self.editingRecipeId = nil
        self.editingText = ""
        self.holdAction = nil
        self.holdTimer = 0
        self.holdRecipeId = nil
        self.holdActionKey = nil
    end

    applyEditingText = function()
        if not self.editingRecipeId then return end
        local num = tonumber(self.editingText)
        if num then
            setQuantity(self.editingRecipeId, num)
        end
    end

    local function backspaceChar()
        if not self.editingRecipeId then return end
        local len = #self.editingText
        if len == 0 then return end
        self.editingText = string.sub(self.editingText, 1, len - 1)
        local num = tonumber(self.editingText)
        if num then
            setQuantity(self.editingRecipeId, num)
        end
        self.caretTimer = 0
        self.caretVisible = true
    end

    local function showNotification(text, isSuccess)
        self.notification = {
            text = text,
            isSuccess = isSuccess,
            timer = 2.0,
        }
    end

    local function startSmeltingJob(ctx, recipe, quantity)
        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship
        local station = getStation(ctx)

        if not player or not ship or not station then
            showNotification("Cannot start job", false)
            return
        end

        local oreCount = Refinery.getPlayerOreCount(ship, recipe.inputId)
        local requiredOre = quantity * recipe.ratio
        if oreCount < requiredOre then
            showNotification("Not enough ore", false)
            return
        end

        local fee = calculateFee(recipe, quantity)
        if player.credits.balance < fee then
            showNotification("Not enough credits", false)
            return
        end

        if RefineryQueue.getFreeSlots(station) <= 0 then
            showNotification("Queue is full", false)
            return
        end

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

        player.credits.balance = player.credits.balance - fee
        ship.cargo.used = Inventory.totalVolume(ship.cargo_hold.slots)

        local success, msg = RefineryQueue.startJob(station, recipe, quantity, oreVolumeToRemove, fee)
        showNotification(success and "Smelting started!" or msg, success)
    end

    -- Per-frame update
    function self.update(ctx, dt)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return end

        if self.editingRecipeId then
            self.caretTimer = self.caretTimer + dt
            if self.caretTimer >= CARET_BLINK then
                self.caretTimer = self.caretTimer - CARET_BLINK
                self.caretVisible = not self.caretVisible
            end
        end

        if self.holdAction and self.holdRecipeId then
            if self.holdActionKey and not love.keyboard.isDown(self.holdActionKey) then
                self.holdAction = nil
                self.holdRecipeId = nil
                self.holdTimer = 0
                self.holdActionKey = nil
                return
            end

            self.holdTimer = self.holdTimer + dt
            if self.holdTimer >= HOLD_DELAY then
                local elapsed = self.holdTimer - HOLD_DELAY
                local repeats = math.floor(elapsed / HOLD_RATE)
                if repeats > 0 then
                    self.holdTimer = HOLD_DELAY + (elapsed % HOLD_RATE)
                    for _ = 1, repeats do
                        if self.holdAction == "inc" then
                            setQuantity(self.holdRecipeId, getQuantity(self.holdRecipeId) + 1)
                        elseif self.holdAction == "dec" then
                            setQuantity(self.holdRecipeId, getQuantity(self.holdRecipeId) - 1)
                        elseif self.holdAction == "backspace" and self.editingRecipeId == self.holdRecipeId then
                            backspaceChar()
                        end
                    end
                end
            end
        end
    end

    function self.hitTest(ctx, x, y)
        local refineryUi = getRefineryUI(ctx)
        return refineryUi and refineryUi.open or false
    end

    function self.draw(ctx)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return end

        local bounds = computeLayout(ctx)

        self.windowFrame:draw(ctx, bounds, {
            title = "REFINERY",
            headerAlpha = 0.55,
            headerLineAlpha = 0.4,
            owner = self,
        })

        RecipePanel.draw(ctx, bounds.leftPanel, self, getQuantity, calculateFee)
        QueuePanel.draw(ctx, bounds.rightPanel, self)

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

            love.graphics.setColor(0.10, 0.08, 0.05, 0.9 * alpha)
            love.graphics.rectangle("fill", nx - 12, ny - 6, tw + 24, th + 12, 4)

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

    function self.keypressed(ctx, key)
        local refineryUi = getRefineryUI(ctx)

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

        if self.editingRecipeId then
            if key == "escape" then
                blurInput()
                return true
            elseif key == "return" or key == "kpenter" then
                applyEditingText()
                blurInput()
                return true
            elseif key == "backspace" then
                backspaceChar()
                self.holdAction = "backspace"
                self.holdRecipeId = self.editingRecipeId
                self.holdTimer = 0
                self.holdActionKey = key
                return true
            elseif key == "up" or key == "kp+" or key == "=" then
                setQuantity(self.editingRecipeId, getQuantity(self.editingRecipeId) + 1)
                self.holdAction = "inc"
                self.holdRecipeId = self.editingRecipeId
                self.holdTimer = 0
                self.holdActionKey = key
                return true
            elseif key == "down" or key == "kp-" or key == "-" then
                setQuantity(self.editingRecipeId, getQuantity(self.editingRecipeId) - 1)
                self.holdAction = "dec"
                self.holdRecipeId = self.editingRecipeId
                self.holdTimer = 0
                self.holdActionKey = key
                return true
            end
        end

        if key == "escape" then
            setOpen(ctx, false)
            return true
        end

        return false
    end

    function self.textinput(ctx, text)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end
        if not self.editingRecipeId then return false end

        if text:match("%d") then
            self.editingText = self.editingText .. text
            local num = tonumber(self.editingText)
            if num then
                setQuantity(self.editingRecipeId, num)
            end
            self.caretTimer = 0
            self.caretVisible = true
            return true
        end

        return false
    end

    function self.mousepressed(ctx, x, y, button)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        local bounds = computeLayout(ctx)

        if pointInRect(x, y, bounds) and ctx.hud then
            ctx.hud:bringToFront(self)
        end

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

            for i, recipe in ipairs(recipes) do
                local ry = bounds.leftPanel.y + (i - 1) * RECIPE_H + PAD - self.scrollY

                if ry + RECIPE_H > bounds.leftPanel.y and ry < bounds.leftPanel.y + bounds.leftPanel.h then
                    local controlY = ry + RECIPE_H - CONTROL_H - CONTROL_BOTTOM_PAD
                    local controlX = bounds.leftPanel.x + 8

                    local inputRect = {
                        x = controlX + CONTROL_BTN_W + CONTROL_GAP,
                        y = controlY,
                        w = CONTROL_INPUT_W,
                        h =
                            CONTROL_H
                    }

                    if pointInRect(x, y, inputRect) then
                        focusInput(recipe.inputId)
                        return true
                    end

                    if pointInRect(x, y, { x = controlX, y = controlY, w = CONTROL_BTN_W, h = CONTROL_H }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) - 1)
                        focusInput(recipe.inputId)
                        return true
                    end

                    local incX = inputRect.x + CONTROL_INPUT_W + CONTROL_GAP
                    if pointInRect(x, y, { x = incX, y = controlY, w = CONTROL_BTN_W, h = CONTROL_H }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) + 1)
                        focusInput(recipe.inputId)
                        return true
                    end

                    local allX = incX + CONTROL_BTN_W + CONTROL_GAP
                    local oreCount = ship and Refinery.getPlayerOreCount(ship, recipe.inputId) or 0
                    local maxQty = math.max(1, math.floor(oreCount / recipe.ratio))
                    if pointInRect(x, y, { x = allX, y = controlY, w = CONTROL_ALL_W, h = CONTROL_H }) then
                        setQuantity(recipe.inputId, maxQty)
                        focusInput(recipe.inputId)
                        return true
                    end

                    local startX = allX + CONTROL_ALL_W + CONTROL_GAP
                    if pointInRect(x, y, { x = startX, y = controlY, w = 70, h = CONTROL_H }) then
                        local qty = getQuantity(recipe.inputId)
                        startSmeltingJob(ctx, recipe, qty)
                        return true
                    end
                end
            end
        end

        -- Work order buttons
        if button == 1 and pointInRect(x, y, bounds.leftPanel) then
            local workOrders = RefineryQueue.getWorkOrders(station)
            local workOrdersHeaderY = bounds.leftPanel.y + math.max(#Refinery.getRecipes(), 1) * RECIPE_H + PAD * 2 -
                self.scrollY

            for i, order in ipairs(workOrders) do
                local oy = workOrdersHeaderY + 18 + (i - 1) * WORK_ORDER_H + PAD
                if oy + WORK_ORDER_H > bounds.leftPanel.y and oy < bounds.leftPanel.y + bounds.leftPanel.h then
                    local btnW = 86
                    local btnH = 22
                    local btnX = bounds.leftPanel.x + bounds.leftPanel.w - btnW - 12
                    local btnY = oy + (WORK_ORDER_H - btnH - PAD)
                    local btnRect = { x = btnX, y = btnY, w = btnW, h = btnH }

                    local btnText
                    local btnEnabled = true

                    if order.rewarded then
                        btnText = nil
                        btnEnabled = false
                    elseif order.completed then
                        btnText = "Turn in"
                    elseif order.accepted then
                        btnText = nil
                        btnEnabled = false
                    else
                        btnText = "Accept"
                        if (station and station.refinery_queue and station.refinery_queue.level or 1) < (order.levelRequired or 1) then
                            btnEnabled = false
                        end
                    end

                    if btnText and btnEnabled and pointInRect(x, y, btnRect) then
                        local success, msg
                        if btnText == "Accept" then
                            success, msg = RefineryQueue.acceptWorkOrder(station, order.id)
                        else
                            success, msg = RefineryQueue.turnInWorkOrder(station, order.id, player)
                        end
                        showNotification(msg, success)
                        return true
                    end
                end
            end
        end

        -- Queue panel clicks
        if button == 1 and pointInRect(x, y, bounds.rightPanel) then
            local jobs = RefineryQueue.getJobs(station)
            local maxSlots = station and station.refinery_queue and station.refinery_queue.maxSlots or 3
            local slotH = Helpers.SLOT_H
            local yOffset = 0

            -- Check for bay slot click first (if bay has a processing job)
            if station and station.refinery_bay then
                local bayStatus = RefineryBaySystem.getBayStatus(station)
                if bayStatus and bayStatus.processing then
                    local sy = bounds.rightPanel.y
                    local baySlotH = slotH - PAD * 2

                    -- Bay collect button
                    if bayStatus.complete then
                        local collectBtnRect = {
                            x = bounds.rightPanel.x + bounds.rightPanel.w - 65,
                            y = sy + 18,
                            w = 58,
                            h = 24
                        }

                        if pointInRect(x, y, collectBtnRect) then
                            local success, msg = RefineryBaySystem.collectBayJob(station, ship)
                            showNotification(msg, success)
                            return true
                        end
                    end
                    yOffset = slotH
                end
            end

            -- Regular queue slot collect buttons
            for i = 1, maxSlots do
                local job = jobs[i]
                if job and RefineryQueue.isJobComplete(job) then
                    local sy = bounds.rightPanel.y + yOffset + (i - 1) * slotH + PAD
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

    function self.mousereleased(ctx, x, y, button)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        if self.windowFrame:mousereleased(ctx, x, y, button) then
            return true
        end

        return false
    end

    function self.mousemoved(ctx, x, y, dx, dy)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        if self.windowFrame:mousemoved(ctx, x, y, dx, dy) then
            return true
        end

        return false
    end

    function self.wheelmoved(ctx, x, y)
        local refineryUi = getRefineryUI(ctx)
        if not refineryUi or not refineryUi.open then return false end

        self.scrollY = math.max(0, self.scrollY - y * 30)
        return true
    end

    return self
end

return makeRefineryWindow()
