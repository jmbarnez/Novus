---@diagnostic disable: undefined-global
-- UI Quest Window Module - Handles quest display and interaction
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

-- Lazy-load QuestSystem to avoid circular dependencies
local QuestSystem

local function getQuestSystem()
    if not QuestSystem then
        QuestSystem = require('src.systems.quest_system')
    end
    return QuestSystem
end

-- Create quest window instance inheriting from WindowBase
local QuestWindow = WindowBase:new{
    width = 560,
    height = 480,
    isOpen = false,
    animAlphaSpeed = 2.5,
}

-- Store current station ID
QuestWindow.currentStationId = nil

-- Public interface for toggling
function QuestWindow:toggle()
    self:setOpen(not self.isOpen)
end

function QuestWindow:getOpen()
    return self.isOpen
end

function QuestWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if not state then
        self.currentStationId = nil
    end
end

-- Override draw to add quest-specific content on top of universal window
---@diagnostic disable-next-line: duplicate-set-field
function QuestWindow:draw(viewportWidth, viewportHeight)
    -- Draw base window (background, top/bottom bars, dividers)
    WindowBase.draw(self)

    if not self.position then return end

    local alpha = self.animAlpha
    if alpha <= 0 then return end

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight

    -- Draw close button using the shared plasma styling
    WindowBase.drawCloseButton(self, x, y, alpha)

    -- Draw quest content
    self:drawQuestContent(x, y, w, h, topBarH, alpha)
end

-- Draw quest content
function QuestWindow:drawQuestContent(x, y, w, h, topBarH, alpha)
    local titleFont = Theme.getFont("lg")
    local font = Theme.getFont("sm")
    local smallFont = Theme.getFont("xs")
    local spacing = Theme.spacing
    
    -- Draw title in top bar area (left-aligned)
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
    love.graphics.setFont(titleFont)
    love.graphics.print("Quest Board", x + spacing.md, y + (topBarH - titleFont:getHeight()) / 2)
    
    -- Draw station name if available (smaller, muted)
    local contentStartY = y + topBarH + spacing.md
    if self.currentStationId then
        local stationLabel = ECS.getComponent(self.currentStationId, "StationLabel")
        if stationLabel and stationLabel[1] then
            love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
            love.graphics.setFont(smallFont)
            love.graphics.print(stationLabel[1], x + spacing.md, contentStartY)
            contentStartY = contentStartY + smallFont:getHeight() + spacing.xs
        end
    end
    
    -- Get quests from the quest system
    local questSys = getQuestSystem()
    local quests = {}
    if questSys and self.currentStationId then
        -- Initialize quest board if needed
        questSys.initQuestBoard(self.currentStationId)
        quests = questSys.getQuests(self.currentStationId)
    end
    
    -- Draw quests in compact list (no bottom bar needed)
    local questStartY = contentStartY + (self.currentStationId and spacing.xs or 0)
    local availableHeight = h - topBarH - (questStartY - y) - spacing.md
    local questHeight = math.floor(availableHeight / math.max(3, #quests)) - spacing.xs
    
    for i, quest in ipairs(quests) do
        self:drawQuest(x + spacing.md, questStartY + (i-1) * (questHeight + spacing.xs), w - spacing.md * 2, questHeight, quest, alpha, i)
    end
    
    -- Draw "no quests" message if empty
    if #quests == 0 then
        local centerY = y + topBarH + (h - topBarH) / 2
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.setFont(font)
        local questText = "No active quests available."
        local questTextW = font:getWidth(questText)
        love.graphics.print(questText, x + (w - questTextW) / 2, centerY - font:getHeight())
        
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
        love.graphics.setFont(smallFont)
        local hintText = "Come back later for new missions!"
        local hintTextW = smallFont:getWidth(hintText)
        love.graphics.print(hintText, x + (w - hintTextW) / 2, centerY + spacing.xs)
    end
end

-- Draw a single quest
function QuestWindow:drawQuest(qx, qy, qw, qh, quest, alpha, index)
    local spacing = Theme.spacing
    local titleFont = Theme.getFont("sm")
    local font = Theme.getFont("xs")
    local buttonFont = Theme.getFont("xs")
    
    -- Quest background (sharp corners)
    local bgColor = Theme.colors.surfaceAlt
    if quest.accepted then
        bgColor = Theme.colors.surfaceLight
    end
    if quest.completed then
        bgColor = Theme.darken(Theme.colors.success, 0.7)
    end
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha)
    love.graphics.rectangle("fill", qx, qy, qw, qh)
    
    -- Quest border (sharp corners, accent for accepted, success for completed)
    local borderColor = Theme.colors.borderAlt
    if quest.accepted then
        borderColor = Theme.colors.accent
    end
    if quest.completed then
        borderColor = Theme.colors.success
    end
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", qx, qy, qw, qh)
    love.graphics.setLineWidth(1)
    
    -- Compact quest layout
    local padding = spacing.sm
    local lineHeight = font:getHeight() + 2
    local currentY = qy + padding
    
    -- Quest title (accent color, bold)
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
    love.graphics.setFont(titleFont)
    love.graphics.print(quest.title, qx + padding, currentY)
    currentY = currentY + titleFont:getHeight() + 2
    
    -- Quest description (wrapped, muted if accepted)
    local descColor = quest.accepted and Theme.colors.textSecondary or Theme.colors.text
    love.graphics.setColor(descColor[1], descColor[2], descColor[3], alpha)
    love.graphics.setFont(font)
    local descW = qw - padding * 2
    local descLines = {}
    local descWords = {}
    for word in quest.description:gmatch("%S+") do
        table.insert(descWords, word)
    end
    local line = ""
    for _, word in ipairs(descWords) do
        local testLine = line == "" and word or line .. " " .. word
        if font:getWidth(testLine) <= descW then
            line = testLine
        else
            if line ~= "" then
                table.insert(descLines, line)
            end
            line = word
        end
    end
    if line ~= "" then
        table.insert(descLines, line)
    end
    for i, lineText in ipairs(descLines) do
        if currentY + lineHeight <= qy + qh - 28 then
            love.graphics.print(lineText, qx + padding, currentY)
            currentY = currentY + lineHeight
        end
    end
    
    -- Reward and progress on same line (compact)
    currentY = qy + qh - 22
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    love.graphics.setFont(font)
    local rewardText = quest.reward .. " cr"
    love.graphics.print(rewardText, qx + padding, currentY)
    
    -- Progress if accepted
    if quest.accepted and quest.requirements then
        local progressText = string.format("%d/%d", quest.requirements.current, quest.requirements.count)
        local progressW = font:getWidth(progressText)
        love.graphics.print(progressText, qx + qw - padding - progressW, currentY)
    end
    
    -- Button (compact, 80px wide, 22px tall)
    local buttonW = 80
    local buttonH = 22
    local buttonX = qx + qw - buttonW - spacing.sm
    local buttonY = qy + spacing.xs
    
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getX(), love.mouse.getY())
    end
    
    if not quest.accepted then
        -- Accept button (manual draw for alpha control)
        local isHovered = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        local buttonColor = isHovered and Theme.colors.successHover or Theme.colors.success
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], alpha)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.setFont(buttonFont)
        local acceptText = "Accept"
        local acceptTextW = buttonFont:getWidth(acceptText)
        love.graphics.print(acceptText, buttonX + (buttonW - acceptTextW) / 2, buttonY + (buttonH - buttonFont:getHeight()) / 2)
    elseif quest.completed then
        -- Turn in button (manual draw for alpha control)
        local isHovered = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        local buttonColor = isHovered and Theme.colors.successHover or Theme.colors.success
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], alpha)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.setFont(buttonFont)
        local turnInText = "Turn In"
        local turnInTextW = buttonFont:getWidth(turnInText)
        love.graphics.print(turnInText, buttonX + (buttonW - turnInTextW) / 2, buttonY + (buttonH - buttonFont:getHeight()) / 2)
    else
        -- Accepted indicator (compact badge)
        love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha * 0.6)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH)
        love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
        love.graphics.setFont(buttonFont)
        local acceptedText = "Active"
        local acceptedTextW = buttonFont:getWidth(acceptedText)
        love.graphics.print(acceptedText, buttonX + (buttonW - acceptedTextW) / 2, buttonY + (buttonH - buttonFont:getHeight()) / 2)
    end
end

-- Handle mouse input
function QuestWindow:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return false end
    
    -- Call parent to handle close button and dragging
    WindowBase.mousepressed(self, x, y, button)
    
    -- If window was closed or dragging started, return true
    if not self.isOpen or self.isDragging then
        return true
    end
    
    -- Convert to UI coordinates for quest button checking
    local mx, my = Scaling.toUI(x, y)
    
    -- Check for quest accept/turn-in buttons
    if button == 1 and self.currentStationId then
        local questSys = getQuestSystem()
        if questSys then
            local quests = questSys.getQuests(self.currentStationId)
            local spacing = Theme.spacing
            local contentStartY = self.position.y + Theme.window.topBarHeight + spacing.md
            
            -- Recalculate station label offset
            local stationLabel = ECS.getComponent(self.currentStationId, "StationLabel")
            if stationLabel and stationLabel[1] then
                local smallFont = Theme.getFont("xs")
                contentStartY = contentStartY + smallFont:getHeight() + spacing.xs + spacing.xs
            end
            
            local availableHeight = self.height - Theme.window.topBarHeight - (contentStartY - self.position.y) - spacing.md
            local questHeight = math.floor(availableHeight / math.max(3, #quests)) - spacing.xs
            
            for i, quest in ipairs(quests) do
                local qx = self.position.x + spacing.md
                local qy = contentStartY + (i-1) * (questHeight + spacing.xs)
                local qw = self.width - spacing.md * 2
                local qh = questHeight
                
                local buttonW = 80
                local buttonH = 22
                local buttonX = qx + qw - buttonW - spacing.sm
                local buttonY = qy + spacing.xs
                
                if mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH then
                    if not quest.accepted then
                        -- Accept quest
                        QuestSystem.acceptQuest(self.currentStationId, quest.id)
                        return true
                    elseif quest.completed then
                        -- Turn in quest
                        if QuestSystem.turnInQuest(self.currentStationId, quest.id) then
                            -- Show notification
                            local Notifications = require('src.ui.notifications')
                            Notifications.add({
                                type = 'quest',
                                text = string.format("Quest completed! +%d credits", quest.reward),
                                timer = 3.0
                            })
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

function QuestWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
end

function QuestWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
end

return QuestWindow

