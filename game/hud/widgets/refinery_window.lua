--- Refinery Window HUD Widget
--- Fullscreen window for ore processing

local Theme = require("game.theme")
local WindowFrame = require("game.hud.window_frame")
local Rect = require("util.rect")
local Refinery = require("game.refinery")
local RefineryUI = require("game.refinery_ui")
local ItemIcons = require("game.item_icons")
local Items = require("game.items")

local pointInRect = Rect.pointInRect

local function makeRefineryWindow()
    local self = {
        windowFrame = WindowFrame.new(),
        scrollY = 0,
        quantities = {},    -- Per-recipe quantity inputs
        notification = nil, -- { text, isSuccess, timer }
    }

    -- Constants
    local WINDOW_W = 550
    local WINDOW_H = 400
    local HEADER_H = 32
    local CONTENT_PAD = 12

    -- State access
    local function getRefineryUI(ctx)
        local world = ctx and ctx.world
        return world and world:getResource("refinery_ui")
    end

    local function getUiCapture(ctx)
        local world = ctx and ctx.world
        return world and world:getResource("ui_capture")
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
        local screenW = ctx and ctx.screenW or 800
        local screenH = ctx and ctx.screenH or 600

        -- Let WindowFrame handle position
        local bounds = self.windowFrame:compute(ctx, WINDOW_W, WINDOW_H, {
            headerH = HEADER_H,
            closeSize = 18,
            closePad = 8,
        })

        -- Content area
        local contentY = bounds.y + HEADER_H + CONTENT_PAD
        local contentH = WINDOW_H - HEADER_H - CONTENT_PAD * 2
        bounds.contentRect = { x = bounds.x + CONTENT_PAD, y = contentY, w = WINDOW_W - CONTENT_PAD * 2, h = contentH }

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

    -- Draw recipe content
    local function drawRecipeContent(ctx, rect)
        local recipes = Refinery.getRecipes()
        local recipeH = 70
        local pad = 8

        local player = ctx.world and ctx.world:getResource("player")
        local ship = player and player.pilot and player.pilot.ship

        love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)

        if #recipes == 0 then
            love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
            love.graphics.print("No recipes available", rect.x + 10, rect.y + 10)
        else
            for i, recipe in ipairs(recipes) do
                local ry = rect.y + (i - 1) * recipeH + pad - self.scrollY

                if ry + recipeH > rect.y and ry < rect.y + rect.h then
                    local recipeRect = { x = rect.x + pad, y = ry, w = rect.w - pad * 2, h = recipeH - pad }
                    local mx, my = love.mouse.getPosition()
                    local hovered = pointInRect(mx, my, recipeRect)

                    -- Background (industrial orange tint)
                    love.graphics.setColor(0.18, 0.14, 0.10, hovered and 0.95 or 0.75)
                    love.graphics.rectangle("fill", recipeRect.x, recipeRect.y, recipeRect.w, recipeRect.h, 4)

                    -- Border
                    love.graphics.setColor(0.70, 0.50, 0.30, hovered and 0.9 or 0.5)
                    love.graphics.setLineWidth(hovered and 2 or 1)
                    love.graphics.rectangle("line", recipeRect.x, recipeRect.y, recipeRect.w, recipeRect.h, 4)

                    -- Input icon
                    local iconSize = 32
                    local iconX = recipeRect.x + 10
                    local iconY = recipeRect.y + (recipeRect.h - iconSize) / 2
                    ItemIcons.draw(recipe.inputId, iconX, iconY, iconSize, iconSize)

                    -- Arrow
                    love.graphics.setColor(0.80, 0.60, 0.30, 0.9)
                    local arrowX = iconX + iconSize + 15
                    local arrowY = recipeRect.y + recipeRect.h / 2
                    love.graphics.polygon("fill",
                        arrowX, arrowY - 6,
                        arrowX + 12, arrowY,
                        arrowX, arrowY + 6
                    )

                    -- Output icon
                    local outIconX = arrowX + 22
                    ItemIcons.draw(recipe.outputId, outIconX, iconY, iconSize, iconSize)

                    -- Recipe text
                    local font = love.graphics.getFont()
                    local textX = outIconX + iconSize + 15
                    love.graphics.setColor(1, 1, 1, 0.95)
                    local ratioText = string.format("%d %s → 1 %s", recipe.ratio, recipe.inputName, recipe.outputName)
                    love.graphics.print(ratioText, textX, recipeRect.y + 10)

                    -- Processing fee
                    love.graphics.setColor(0.85, 0.80, 0.40, 0.9)
                    local feeText = string.format("Fee: %d cr each", recipe.processingFee)
                    love.graphics.print(feeText, textX, recipeRect.y + 28)

                    -- Available ore count
                    local oreCount = ship and Refinery.getPlayerOreCount(ship, recipe.inputId) or 0
                    love.graphics.setColor(0.6, 0.8, 0.6, 0.8)
                    local stockText = string.format("Have: %d ore", oreCount)
                    love.graphics.print(stockText, textX, recipeRect.y + 44)

                    -- Quantity controls and process button (right side)
                    local qty = getQuantity(recipe.inputId)
                    local qtyX = recipeRect.x + recipeRect.w - 170
                    local qtyY = recipeRect.y + 20

                    -- Minus button
                    local minusBtnRect = { x = qtyX, y = qtyY, w = 22, h = 22 }
                    local minusHover = pointInRect(mx, my, minusBtnRect)
                    love.graphics.setColor(0.30, 0.25, 0.18, minusHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.9)
                    love.graphics.rectangle("line", minusBtnRect.x, minusBtnRect.y, minusBtnRect.w, minusBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.print("-", minusBtnRect.x + 7, minusBtnRect.y + 3)

                    -- Quantity display
                    local qtyText = tostring(qty)
                    local qtyTw = font:getWidth(qtyText)
                    love.graphics.setColor(0.14, 0.12, 0.08, 0.9)
                    love.graphics.rectangle("fill", qtyX + 26, qtyY, 32, 22, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
                    love.graphics.rectangle("line", qtyX + 26, qtyY, 32, 22, 3)
                    love.graphics.setColor(1, 1, 1, 0.95)
                    love.graphics.print(qtyText, qtyX + 26 + (32 - qtyTw) / 2, qtyY + 3)

                    -- Plus button
                    local plusBtnRect = { x = qtyX + 62, y = qtyY, w = 22, h = 22 }
                    local plusHover = pointInRect(mx, my, plusBtnRect)
                    love.graphics.setColor(0.30, 0.25, 0.18, plusHover and 1.0 or 0.8)
                    love.graphics.rectangle("fill", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                    love.graphics.setColor(0.70, 0.55, 0.35, 0.9)
                    love.graphics.rectangle("line", plusBtnRect.x, plusBtnRect.y, plusBtnRect.w, plusBtnRect.h, 3)
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.print("+", plusBtnRect.x + 6, plusBtnRect.y + 3)

                    -- Process button
                    local canProcess = oreCount >= qty * recipe.ratio
                    local processBtnRect = { x = qtyX + 92, y = qtyY, w = 70, h = 22 }
                    local processHover = pointInRect(mx, my, processBtnRect) and canProcess

                    if canProcess then
                        love.graphics.setColor(0.50, 0.35, 0.15, processHover and 1.0 or 0.8)
                        love.graphics.rectangle("fill", processBtnRect.x, processBtnRect.y, processBtnRect.w,
                            processBtnRect.h, 3)
                        love.graphics.setColor(0.90, 0.65, 0.30, 0.9)
                        love.graphics.rectangle("line", processBtnRect.x, processBtnRect.y, processBtnRect.w,
                            processBtnRect.h, 3)
                        love.graphics.setColor(1, 1, 1, 0.95)
                    else
                        love.graphics.setColor(0.20, 0.18, 0.15, 0.5)
                        love.graphics.rectangle("fill", processBtnRect.x, processBtnRect.y, processBtnRect.w,
                            processBtnRect.h, 3)
                        love.graphics.setColor(0.40, 0.35, 0.30, 0.5)
                        love.graphics.rectangle("line", processBtnRect.x, processBtnRect.y, processBtnRect.w,
                            processBtnRect.h, 3)
                        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                    end
                    love.graphics.print("Process", processBtnRect.x + 10, processBtnRect.y + 3)
                end
            end
        end

        love.graphics.setScissor()
        love.graphics.setLineWidth(1)
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

        local theme = (ctx and ctx.theme) or Theme
        local bounds = computeLayout(ctx)

        -- Window frame
        self.windowFrame:draw(ctx, bounds, {
            title = "REFINERY",
            headerAlpha = 0.55,
            headerLineAlpha = 0.4,
            owner = self,
        })

        -- Content
        drawRecipeContent(ctx, bounds.contentRect)

        -- Draw notification
        if self.notification and self.notification.timer and self.notification.timer > 0 then
            local notif = self.notification
            local alpha = math.min(1, notif.timer / 0.5)
            local font = love.graphics.getFont()
            local text = notif.text
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local nx = bounds.x + (WINDOW_W - tw) / 2
            local ny = bounds.y + WINDOW_H - 50

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

        -- Don't block other keys - allow other windows to handle them
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

        -- Recipe button clicks
        if button == 1 and pointInRect(x, y, bounds.contentRect) then
            local recipes = Refinery.getRecipes()
            local recipeH = 70
            local pad = 8

            local player = ctx.world and ctx.world:getResource("player")
            local ship = player and player.pilot and player.pilot.ship

            for i, recipe in ipairs(recipes) do
                local ry = bounds.contentRect.y + (i - 1) * recipeH + pad - self.scrollY
                local recipeRect = {
                    x = bounds.contentRect.x + pad,
                    y = ry,
                    w = bounds.contentRect.w - pad * 2,
                    h = recipeH - pad
                }

                if ry + recipeH > bounds.contentRect.y and ry < bounds.contentRect.y + bounds.contentRect.h then
                    local qtyX = recipeRect.x + recipeRect.w - 170
                    local qtyY = ry + 20

                    -- Minus button
                    if pointInRect(x, y, { x = qtyX, y = qtyY, w = 22, h = 22 }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) - 1)
                        return true
                    end

                    -- Plus button
                    if pointInRect(x, y, { x = qtyX + 62, y = qtyY, w = 22, h = 22 }) then
                        setQuantity(recipe.inputId, getQuantity(recipe.inputId) + 1)
                        return true
                    end

                    -- Process button
                    if pointInRect(x, y, { x = qtyX + 92, y = qtyY, w = 70, h = 22 }) then
                        local qty = getQuantity(recipe.inputId)
                        if player and ship then
                            local success, msg = Refinery.processOre(player, ship, recipe.inputId, qty)
                            showNotification(msg, success)
                        end
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
