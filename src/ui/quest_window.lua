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
    width = 700,
    height = 600,
    isOpen = false,
    animAlphaSpeed = 2.5,
    elasticitySpring = 18,
    elasticityDamping = 0.7,
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

    -- Check if should be visible
    if not self.isOpen and not self.animAlphaActive then return end

    local alpha = self.animAlpha
    if alpha <= 0 then return end

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight

    -- Draw close button
    self:drawCloseButton(x, y, alpha)

    -- Draw quest content
    self:drawQuestContent(x, y, w, h, topBarH, bottomBarH, alpha)
end

-- Draw close button
function QuestWindow:drawCloseButton(x, y, alpha)
    local closeSize = 20
    local closeX = x + self.width - closeSize - 8
    local closeY = y + 8
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getX(), love.mouse.getY())
    end
    
    local isHovered = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
    
    love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
    if isHovered then
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    end
    
    local font = Theme.getFont(18)
    love.graphics.setFont(font)
    love.graphics.print("×", closeX, closeY)
end

-- Draw quest content
function QuestWindow:drawQuestContent(x, y, w, h, topBarH, bottomBarH, alpha)
    local font = Theme.getFont(16)
    local titleFont = Theme.getFont(20)
    local smallFont = Theme.getFont(12)
    
    -- Draw title
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(titleFont)
    local title = "Quest Board"
    local titleW = titleFont:getWidth(title)
    love.graphics.print(title, x + (w - titleW) / 2, y + topBarH + 20)
    
    -- Draw station name if available
    if self.currentStationId then
        local stationLabel = ECS.getComponent(self.currentStationId, "StationLabel")
        if stationLabel and stationLabel[1] then
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
            love.graphics.setFont(font)
            love.graphics.print(stationLabel[1], x + 20, y + topBarH + 50)
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
    
    -- Draw quests
    local questStartY = y + topBarH + 80
    local questHeight = (h - topBarH - bottomBarH - 80 - 20) / 3
    
    for i, quest in ipairs(quests) do
        self:drawQuest(x + 16, questStartY + (i-1) * questHeight, w - 32, questHeight - 4, quest, alpha, i)
    end
    
    -- Draw "no quests" message if empty
    if #quests == 0 then
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(font)
        local questText = "No active quests available."
        local questTextW = font:getWidth(questText)
        love.graphics.print(questText, x + (w - questTextW) / 2, questStartY + (h - topBarH - bottomBarH - 80) / 2 - 10)
        
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
        love.graphics.setFont(smallFont)
        local hintText = "Come back later for new missions!"
        local hintTextW = smallFont:getWidth(hintText)
        love.graphics.print(hintText, x + (w - hintTextW) / 2, questStartY + (h - topBarH - bottomBarH - 80) / 2 + 20)
    end
end

-- Draw a single quest
function QuestWindow:drawQuest(qx, qy, qw, qh, quest, alpha, index)
    local font = Theme.getFont(14)
    local smallFont = Theme.getFont(11)
    local buttonFont = Theme.getFont(12)
    
    -- Quest background
    local bgColor = Theme.colors.bgMedium
    if quest.accepted then
        bgColor = {bgColor[1] * 0.8, bgColor[2] * 0.8, bgColor[3] * 0.8}
    end
    if quest.completed then
        bgColor = {0.1, 0.3, 0.1, 1} -- Green tint for completed
    end
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], alpha * 0.5)
    love.graphics.rectangle("fill", qx, qy, qw, qh, 4, 4)
    
    -- Quest border
    local borderColor = Theme.colors.borderDark
    if quest.accepted then
        borderColor = Theme.colors.textAccent
    end
    if quest.completed then
        borderColor = Theme.colors.buttonYes
    end
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", qx, qy, qw, qh, 4, 4)
    love.graphics.setLineWidth(1)
    
    -- Quest title
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(font)
    love.graphics.print(quest.title, qx + 12, qy + 8)
    
    -- Quest description
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(smallFont)
    love.graphics.print(quest.description, qx + 12, qy + 28)
    
    -- Quest reward
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(smallFont)
    local rewardText = "Reward: " .. quest.reward .. " credits"
    love.graphics.print(rewardText, qx + 12, qy + 45)
    
    -- Show progress if accepted
    if quest.accepted and quest.requirements then
        local progressText = string.format("Progress: %d/%d", quest.requirements.current, quest.requirements.count)
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
        love.graphics.setFont(smallFont)
        love.graphics.print(progressText, qx + 12, qy + 60)
    end
    
    -- Button dimensions (used in all branches)
    local buttonW = 100
    local buttonH = 24
    
    -- Accept button (if not accepted)
    if not quest.accepted then
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getX(), love.mouse.getY())
        end
        local buttonX = qx + qw - buttonW - 12
        local buttonY = qy + qh - buttonH - 8
        
        local isHovered = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        
        local buttonColor = Theme.colors.buttonYes
        if isHovered then
            buttonColor = {buttonColor[1] * 1.2, buttonColor[2] * 1.2, buttonColor[3] * 1.2}
        end
        
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], alpha)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 3, 3)
        
        love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH, 3, 3)
        
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(buttonFont)
        local acceptText = "Accept"
        local acceptTextW = buttonFont:getWidth(acceptText)
        love.graphics.print(acceptText, buttonX + (buttonW - acceptTextW) / 2, buttonY + (buttonH - buttonFont:getHeight()) / 2)
    elseif quest.completed then
        -- Turn in button for completed quests
        local mx, my = Scaling.toUI(love.mouse.getX(), love.mouse.getY())
        local buttonX = qx + qw - buttonW - 12
        local buttonY = qy + qh - buttonH - 8
        
        local isHovered = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH
        
        local buttonColor = Theme.colors.buttonYes
        if isHovered then
            buttonColor = {buttonColor[1] * 1.2, buttonColor[2] * 1.2, buttonColor[3] * 1.2}
        end
        
        love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], alpha)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 3, 3)
        
        love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH, 3, 3)
        
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(buttonFont)
        local turnInText = "Turn In"
        local turnInTextW = buttonFont:getWidth(turnInText)
        love.graphics.print(turnInText, buttonX + (buttonW - turnInTextW) / 2, buttonY + (buttonH - buttonFont:getHeight()) / 2)
    else
        -- Accepted indicator
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        love.graphics.setFont(smallFont)
        local acceptedText = "✓ Accepted"
        love.graphics.print(acceptedText, qx + qw - 12 - smallFont:getWidth(acceptedText), qy + qh - buttonH - 8)
    end
end

-- Handle mouse input
function QuestWindow:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return false end
    
    -- Check close button
    local closeSize = 20
    local closeX = self.position.x + self.width - closeSize - 8
    local closeY = self.position.y + 8
    
    if x >= closeX and x <= closeX + closeSize and y >= closeY and y <= closeY + closeSize then
        self:setOpen(false)
        return true
    end
    
    -- Check for dragging
    if button == 1 and y >= self.position.y and y <= self.position.y + Theme.window.topBarHeight then
        self.isDragging = true
        self.dragOffset = {x = x - self.position.x, y = y - self.position.y}
        return true
    end
    
    -- Check for quest accept/turn-in buttons
    if button == 1 and self.currentStationId then
        local questSys = getQuestSystem()
        if questSys then
            local quests = questSys.getQuests(self.currentStationId)
            local questStartY = self.position.y + Theme.window.topBarHeight + 80
            local questHeight = (self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 80 - 20) / 3
            
            for i, quest in ipairs(quests) do
                local qx = self.position.x + 16
                local qy = questStartY + (i-1) * questHeight
                local qw = self.width - 32
                local qh = questHeight - 4
                
                local buttonW = 100
                local buttonH = 24
                local buttonX = qx + qw - buttonW - 12
                local buttonY = qy + qh - buttonH - 8
                
                if x >= buttonX and x <= buttonX + buttonW and y >= buttonY and y <= buttonY + buttonH then
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
    if button == 1 then
        self.isDragging = false
    end
end

function QuestWindow:mousemoved(x, y, dx, dy)
    if self.isDragging and self.position then
        self.position.x = x - self.dragOffset.x
        self.position.y = y - self.dragOffset.y
    end
end

return QuestWindow

