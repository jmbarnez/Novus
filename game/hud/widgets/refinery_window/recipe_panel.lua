--- Refinery Window Recipe Panel
--- Draws the recipe list and work orders on the left side

local Refinery = require("game.systems.refinery")
local RefineryQueue = require("game.systems.refinery_queue")
local ItemIcons = require("game.item_icons")
local Helpers = require("game.hud.widgets.refinery_window.helpers")

local RecipePanel = {}

local pointInRect = Helpers.pointInRect
local STATUS_COLORS = Helpers.STATUS_COLORS
local TEXT_COLORS = Helpers.TEXT_COLORS
local CONTROL_BTN_W = Helpers.CONTROL_BTN_W
local CONTROL_INPUT_W = Helpers.CONTROL_INPUT_W
local CONTROL_ALL_W = Helpers.CONTROL_ALL_W
local CONTROL_GAP = Helpers.CONTROL_GAP
local CONTROL_H = Helpers.CONTROL_H
local CONTROL_BOTTOM_PAD = Helpers.CONTROL_BOTTOM_PAD
local RECIPE_H = Helpers.RECIPE_H
local WORK_ORDER_H = Helpers.WORK_ORDER_H
local PAD = Helpers.PAD

--- Draw the recipe panel
--- @param ctx table Context
--- @param rect table Panel bounds {x, y, w, h}
--- @param state table Widget state (quantities, scrollY, fonts, editingRecipeId, etc.)
--- @param getQuantity function Get quantity for recipe
--- @param calculateFee function Calculate fee for recipe
function RecipePanel.draw(ctx, rect, state, getQuantity, calculateFee)
    local recipes = Refinery.getRecipes()
    local recipeH = RECIPE_H
    local pad = PAD

    local player = ctx.world and ctx.world:getResource("player")
    local ship = player and player.pilot and player.pilot.ship
    local station = Helpers.getStation(ctx)
    local freeSlots = RefineryQueue.getFreeSlots(station)

    -- Panel header
    love.graphics.setFont(state.fonts.status)
    love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
    love.graphics.print("RECIPES", rect.x, rect.y + 2)

    love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.label)

    -- Recipes list
    local recipesStartY = rect.y + 24
    if #recipes == 0 then
        love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
        love.graphics.print("No recipes available", rect.x + 10, recipesStartY + 10)
    else
        for i, recipe in ipairs(recipes) do
            local ry = recipesStartY + (i - 1) * recipeH + pad - state.scrollY

            if ry + recipeH > rect.y and ry < rect.y + rect.h then
                RecipePanel.drawRecipeRow(ctx, rect, state, recipe, ry, recipeH, pad, ship, freeSlots, player,
                    getQuantity, calculateFee)
            end
        end
    end

    -- Work orders list (below recipes)
    local workOrders = RefineryQueue.getWorkOrders(station)
    local workOrdersHeaderY = recipesStartY + math.max(#recipes, 1) * recipeH + pad * 2 - state.scrollY

    if #workOrders > 0 and workOrdersHeaderY < rect.y + rect.h then
        love.graphics.setFont(state.fonts.status)
        love.graphics.setColor(0.9, 0.7, 0.4, 0.9)
        love.graphics.print("JOBS", rect.x, workOrdersHeaderY)

        for i, order in ipairs(workOrders) do
            local oy = workOrdersHeaderY + 18 + (i - 1) * WORK_ORDER_H + pad
            if oy + WORK_ORDER_H > rect.y and oy < rect.y + rect.h then
                RecipePanel.drawWorkOrderRow(ctx, rect, state, order, oy, station)
            end
        end
    end

    love.graphics.setScissor()
    love.graphics.setLineWidth(1)
end

--- Draw a single recipe row
function RecipePanel.drawRecipeRow(ctx, rect, state, recipe, ry, recipeH, pad, ship, freeSlots, player, getQuantity,
                                   calculateFee)
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

    -- Input/Output icons
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
    local ratioText = string.format("%d %s -> 1 %s", recipe.ratio, recipe.inputName, recipe.outputName)
    love.graphics.setFont(state.fonts.label)
    love.graphics.print(ratioText, textX, recipeRect.y + 8)

    -- Time per unit
    love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
    local timeText = string.format("Time: %s each", Helpers.formatTime(recipe.timePerUnit))
    love.graphics.print(timeText, textX, recipeRect.y + 24)

    -- Available ore count
    local oreCount = ship and Refinery.getPlayerOreCount(ship, recipe.inputId) or 0
    love.graphics.setColor(0.6, 0.8, 0.6, 0.8)
    local stockText = string.format("Have: %d ore", oreCount)
    love.graphics.print(stockText, textX, recipeRect.y + 40)

    -- Quantity controls
    local qty = getQuantity(recipe.inputId)
    local controlY = recipeRect.y + recipeRect.h - CONTROL_H - CONTROL_BOTTOM_PAD
    local controlX = recipeRect.x + 8

    -- Decrement button
    local decRect = { x = controlX, y = controlY, w = CONTROL_BTN_W, h = CONTROL_H }
    local decHover = pointInRect(mx, my, decRect)
    love.graphics.setColor(0.25, 0.20, 0.15, decHover and 1.0 or 0.8)
    love.graphics.rectangle("fill", decRect.x, decRect.y, decRect.w, decRect.h, 3)
    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
    love.graphics.rectangle("line", decRect.x, decRect.y, decRect.w, decRect.h, 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("-", decRect.x + 7, decRect.y + 2)

    -- Input field
    local inputRect = { x = decRect.x + CONTROL_BTN_W + CONTROL_GAP, y = controlY, w = CONTROL_INPUT_W, h = CONTROL_H }
    love.graphics.setFont(state.fonts.input)
    love.graphics.setColor(0.14, 0.12, 0.08, 0.9)
    love.graphics.rectangle("fill", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 3)
    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
    love.graphics.rectangle("line", inputRect.x, inputRect.y, inputRect.w, inputRect.h, 3)
    love.graphics.setColor(1, 1, 1, 0.95)

    local isEditing = state.editingRecipeId == recipe.inputId
    local text = isEditing and state.editingText or tostring(qty)
    love.graphics.print(text, inputRect.x + 8, inputRect.y + 3)

    if isEditing and state.caretVisible then
        local font = love.graphics.getFont()
        local tw = font:getWidth(text)
        local cx = inputRect.x + 8 + tw + 1
        local cy0 = inputRect.y + 4
        local cy1 = inputRect.y + CONTROL_H - 4
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.line(cx, cy0, cx, cy1)
    end

    -- Increment button
    local incRect = { x = inputRect.x + CONTROL_INPUT_W + CONTROL_GAP, y = controlY, w = CONTROL_BTN_W, h = CONTROL_H }
    local incHover = pointInRect(mx, my, incRect)
    love.graphics.setColor(0.25, 0.20, 0.15, incHover and 1.0 or 0.8)
    love.graphics.rectangle("fill", incRect.x, incRect.y, incRect.w, incRect.h, 3)
    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
    love.graphics.rectangle("line", incRect.x, incRect.y, incRect.w, incRect.h, 3)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("+", incRect.x + 6, incRect.y + 2)

    -- All button
    local allRect = { x = incRect.x + CONTROL_BTN_W + CONTROL_GAP, y = controlY, w = CONTROL_ALL_W, h = CONTROL_H }
    local allHover = pointInRect(mx, my, allRect)
    love.graphics.setColor(0.25, 0.20, 0.12, allHover and 1.0 or 0.8)
    love.graphics.rectangle("fill", allRect.x, allRect.y, allRect.w, allRect.h, 3)
    love.graphics.setColor(0.70, 0.55, 0.35, 0.7)
    love.graphics.rectangle("line", allRect.x, allRect.y, allRect.w, allRect.h, 3)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print("All", allRect.x + 6, allRect.y + 3)

    -- Start button
    local requiredOre = qty * recipe.ratio
    local fee = calculateFee(recipe, qty)
    local playerCredits = (player and player.credits and player.credits.balance) or 0
    local canStart = oreCount >= requiredOre and playerCredits >= fee and freeSlots > 0

    local startBtnRect = { x = allRect.x + CONTROL_ALL_W + CONTROL_GAP, y = controlY, w = 70, h = CONTROL_H }
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
    love.graphics.setFont(state.fonts.label)
    love.graphics.print("Start", startBtnRect.x + 16, startBtnRect.y + 3)

    -- Fee display
    love.graphics.setColor(0.85, 0.80, 0.40, 0.9)
    love.graphics.print(string.format("%d cr", fee), startBtnRect.x + startBtnRect.w + 10, controlY + 3)
end

--- Draw a single work order row
function RecipePanel.drawWorkOrderRow(ctx, rect, state, order, oy, station)
    local orderRect = { x = rect.x, y = oy, w = rect.w, h = WORK_ORDER_H - PAD }
    local mx, my = love.mouse.getPosition()
    local hovered = pointInRect(mx, my, orderRect)

    -- Background
    love.graphics.setColor(0.14, 0.12, 0.08, hovered and 0.9 or 0.75)
    love.graphics.rectangle("fill", orderRect.x, orderRect.y, orderRect.w, orderRect.h, 4)
    love.graphics.setColor(0.65, 0.48, 0.28, hovered and 0.9 or 0.6)
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", orderRect.x, orderRect.y, orderRect.w, orderRect.h, 4)

    love.graphics.setFont(state.fonts.label)

    -- Description
    love.graphics.setColor(TEXT_COLORS.description[1], TEXT_COLORS.description[2],
        TEXT_COLORS.description[3], TEXT_COLORS.description[4])
    love.graphics.print(order.description or ("Job " .. tostring(order.id)), orderRect.x + 10, orderRect.y + 6)

    -- Progress
    love.graphics.setFont(state.fonts.reward)
    local progressText = string.format("%d / %d ingots", order.current or 0, order.amount or 0)
    love.graphics.setColor(TEXT_COLORS.amount[1], TEXT_COLORS.amount[2], TEXT_COLORS.amount[3], TEXT_COLORS.amount[4])
    love.graphics.print(progressText, orderRect.x + 10, orderRect.y + 26)

    -- Reward
    local rewardText = string.format("Reward: %d cr", order.rewardCredits or 0)
    love.graphics.setColor(TEXT_COLORS.reward[1], TEXT_COLORS.reward[2], TEXT_COLORS.reward[3], TEXT_COLORS.reward[4])
    love.graphics.print(rewardText, orderRect.x + 10, orderRect.y + 44)

    -- Level requirement
    love.graphics.setFont(state.fonts.label)
    local levelText = string.format("Req. Level %d", order.levelRequired or 1)
    love.graphics.setColor(TEXT_COLORS.level[1], TEXT_COLORS.level[2], TEXT_COLORS.level[3], TEXT_COLORS.level[4])
    love.graphics.print(levelText, orderRect.x + orderRect.w - 120, orderRect.y + 6)

    -- Status / action button
    local btnW = 86
    local btnH = 22
    local btnX = orderRect.x + orderRect.w - btnW - 12
    local btnY = orderRect.y + orderRect.h - btnH - 8
    local btnRect = { x = btnX, y = btnY, w = btnW, h = btnH }
    local btnHover = pointInRect(mx, my, btnRect)

    local statusText
    local btnText
    local btnEnabled = true
    local progressAmount = order.current or 0

    if order.rewarded then
        statusText = "TURNED IN"
        btnText = nil
        btnEnabled = false
    elseif order.completed then
        statusText = "COMPLETED"
        btnText = "Turn in"
    elseif order.accepted then
        if progressAmount > 0 then
            statusText = "IN PROGRESS"
        else
            statusText = "ACTIVE"
        end
        btnText = nil
        btnEnabled = false
    else
        btnText = "Accept"
        if (station and station.refinery_queue and station.refinery_queue.level or 1) < (order.levelRequired or 1) then
            btnEnabled = false
        end
    end

    -- Status text
    if statusText then
        local color = STATUS_COLORS.active
        if statusText == "IN PROGRESS" then
            color = STATUS_COLORS.progress
        elseif statusText == "COMPLETED" then
            color = STATUS_COLORS.completed
        elseif statusText == "TURNED IN" then
            color = STATUS_COLORS.turnedin
        end
        love.graphics.setFont(state.fonts.status)
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.print(statusText, orderRect.x + 10, orderRect.y + orderRect.h - 24)
    end

    -- Button
    if btnText then
        love.graphics.setFont(state.fonts.label)
        if btnEnabled then
            love.graphics.setColor(0.20, 0.50, 0.35, btnHover and 1.0 or 0.85)
            love.graphics.rectangle("fill", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
            love.graphics.setColor(0.30, 0.80, 0.50, 0.9)
            love.graphics.rectangle("line", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
            love.graphics.setColor(1, 1, 1, 0.95)
        else
            love.graphics.setColor(0.20, 0.20, 0.20, 0.5)
            love.graphics.rectangle("fill", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
            love.graphics.setColor(0.35, 0.35, 0.35, 0.5)
            love.graphics.rectangle("line", btnRect.x, btnRect.y, btnRect.w, btnRect.h, 3)
            love.graphics.setColor(0.7, 0.7, 0.7, 0.6)
        end
        love.graphics.print(btnText, btnRect.x + 12, btnRect.y + 4)
    end
end

return RecipePanel
