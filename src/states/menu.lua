---@diagnostic disable: undefined-global

local Gamestate     = require "lib.hump.gamestate"
local Utils         = require "src.utils.utils"
local Theme         = require "src.ui.theme"
local Config        = require "src.config"
local Background    = require "src.rendering.background"
local NewGameState  = require "src.states.newgame"
local SaveManager   = require "src.managers.save_manager"
local SoundManager  = require "src.managers.sound_manager"
local SettingsPanel = require "src.ui.settings_panel"

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local nameAdjectives = {
    "Swift",
    "Crimson",
    "Silent",
    "Luminous",
    "Iron",
    "Void",
    "Solar",
    "Nebula",
}

local nameNouns = {
    "Ranger",
    "Voyager",
    "Drifter",
    "Phoenix",
    "Comet",
    "Warden",
    "Nomad",
    "Specter",
}

local function randomFrom(list)
    return list[math.random(1, #list)]
end

local function generateRandomDisplayName()
    return randomFrom(nameAdjectives) .. " " .. randomFrom(nameNouns)
end

local function getJoinDialogLayout()
    local sw, sh = love.graphics.getDimensions()
    local boxWidth = 420
    local boxHeight = 250
    local boxX = (sw - boxWidth) / 2
    local boxY = (sh - boxHeight) / 2

    local labelFont = Theme.getFont("button")
    local labelH = labelFont:getHeight()

    local titleY = boxY + 20
    local ipLabelY = titleY + labelH + 10
    local ipY = ipLabelY + labelH + 6
    local nameLabelY = ipY + labelH + 16
    local nameY = nameLabelY + labelH + 6

    local ipRect = {
        x = boxX + 20,
        y = ipY,
        w = boxWidth - 40,
        h = 40,
    }

    local nameRect = {
        x = boxX + 20,
        y = nameY,
        w = boxWidth - 180,
        h = 40,
    }

    local randomBtnWidth = 140
    local randomBtnHeight = 40
    local randomRect = {
        x = boxX + boxWidth - randomBtnWidth - 20,
        y = nameY,
        w = randomBtnWidth,
        h = randomBtnHeight,
    }

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        titleY = titleY,
        ipLabelY = ipLabelY,
        nameLabelY = nameLabelY,
        instructionsY = boxY + boxHeight - 40,
        ipRect = ipRect,
        nameRect = nameRect,
        randomRect = randomRect,
    }
end

local function getLoadDialogLayout()
    local sw, sh = love.graphics.getDimensions()
    local boxWidth = 420
    local boxHeight = 260
    local boxX = (sw - boxWidth) / 2
    local boxY = (sh - boxHeight) / 2

    local buttonWidth = 260
    local buttonHeight = Theme.spacing.buttonHeight or 42
    local buttonSpacing = 12
    local startX = boxX + (boxWidth - buttonWidth) * 0.5
    local startY = boxY + 70

    local slotRects = {}
    for slot = 1, 3 do
        local y = startY + (slot - 1) * (buttonHeight + buttonSpacing)
        slotRects[slot] = {
            x = startX,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        }
    end

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        titleY = boxY + 20,
        slotRects = slotRects,
    }
end

local function drawModalOverlay(sw, sh)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
end

local function drawDialogBox(layout)
    local boxX = layout.boxX
    local boxY = layout.boxY
    local boxWidth = layout.boxWidth
    local boxHeight = layout.boxHeight
    local rounding = Theme.shapes.buttonRounding or 0
    local outlineWidth = Theme.shapes.outlineWidth or 1.5

    local bgColor = Theme.getBackgroundColor()
    local buttonColors = Theme.colors.button

    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, rounding, rounding)
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.setColor(buttonColors.outline)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, rounding, rounding)
end

local MenuState = {}

function MenuState:enter()
    -- Initialize menu state (no animated background here)

    -- Fonts
    self.fontTitle = Theme.getFont("title")
    self.fontButton = Theme.getFont("button")

    if not self.background then
        self.background = Background.new()
    end

    if not self.titleShader then
        self.titleShader = love.graphics.newShader("assets/shaders/title_aurora.glsl")
        self.shaderTime = 0
    end
    
    SoundManager.play_music("intro", { loop = true })

    self.buttons = {
        {
            label = "NEW GAME",
            action = function()
                Gamestate.switch(NewGameState)
            end,
        },
        {
            label = "LOAD GAME",
            action = function()
                self.load_menu_open = true
                self.load_hovered_slot = nil
                self.load_active_slot = nil
            end,
        },
        {
            label = "JOIN GAME",
            action = function()
                self.ip_input_mode = true
                self.ip_input = "localhost"
                self.cursor_blink_time = 0
                self.cursor_visible = true
            end,
        },
        {
            label = "SETTINGS",
            action = function()
                self.settings_open = true
                if SettingsPanel and SettingsPanel.reset then
                    SettingsPanel.reset()
                end
            end,
        },
        {
            label = "EXIT",
            action = function()
                love.event.quit()
            end,
        },
    }

    self.buttonRects = {}
    self.hoveredButton = nil
    self.activeButton = nil
    self.mouseWasDown = false

    -- Display name field on main menu
    self.display_name_input = Config.PLAYER_NAME or generateRandomDisplayName()
    self.editing_display_name = false

    -- IP Input state (join dialog)
    self.ip_input_mode = false
    self.ip_input = "localhost"
    self.cursor_blink_time = 0
    self.cursor_visible = true
    self.load_menu_open = false
    self.load_hovered_slot = nil
    self.load_active_slot = nil
    self.settings_open = false
end

function MenuState:update(dt)
    local prevHovered = self.hoveredButton

    if self.background then
        self.background:update(dt)
    end

    if self.titleShader then
        self.shaderTime = self.shaderTime + dt
        self.titleShader:send("time", self.shaderTime)
    end

    -- Update cursor blink
    self.cursor_blink_time = self.cursor_blink_time + dt
    if self.cursor_blink_time >= 0.5 then
        self.cursor_visible = not self.cursor_visible
        self.cursor_blink_time = 0
    end

    if self.settings_open then
        if SettingsPanel and SettingsPanel.update then
            SettingsPanel.update(dt)
        end
        self.mouseWasDown = love.mouse.isDown(1)
        return
    end

    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()
    local isDown = love.mouse.isDown(1)

    if self.load_menu_open then
        local prevHoveredSlot = self.load_hovered_slot
        self.load_hovered_slot = nil
        local layout = getLoadDialogLayout()
        for slot, rect in ipairs(layout.slotRects) do
            if pointInRect(mouseX, mouseY, rect) then
                self.load_hovered_slot = slot
                break
            end
        end

        if self.load_hovered_slot and self.load_hovered_slot ~= prevHoveredSlot and SaveManager.has_save(self.load_hovered_slot) then
            SoundManager.play_sound("button_hover")
        end

        if isDown and not self.mouseWasDown then
            self.load_active_slot = self.load_hovered_slot
        elseif not isDown and self.mouseWasDown then
            if self.load_active_slot and self.load_hovered_slot == self.load_active_slot then
                local slot = self.load_active_slot
                if SaveManager.has_save(slot) then
                    SoundManager.play_sound("button_click")
                    Gamestate.switch(require("src.states.play"), { mode = "load", slot = slot })
                end
            end
            self.load_active_slot = nil
        end

        self.mouseWasDown = isDown
        return
    end

    if not self.ip_input_mode then
        self.hoveredButton = nil
        for index, rect in ipairs(self.buttonRects) do
            if pointInRect(mouseX, mouseY, rect) then
                self.hoveredButton = index
                break
            end
        end
    else
        self.hoveredButton = nil
    end

    if self.ip_input_mode then
        local layout = getJoinDialogLayout()
        if isDown and not self.mouseWasDown then
            if pointInRect(mouseX, mouseY, layout.ipRect) then
                -- Focus IP field only
            end
        end
    else
        -- Handle clicks on main-menu display name field
        if isDown and not self.mouseWasDown then
            local sw, sh = love.graphics.getDimensions()
            local fieldWidth, fieldHeight = 260, 40
            local randomWidth = 140
            local totalWidth = fieldWidth + 12 + randomWidth
            local startX = (sw - totalWidth) * 0.5
            local bottomMargin = 60
            local fieldY = sh - bottomMargin - fieldHeight

            local nameRect = { x = startX, y = fieldY, w = fieldWidth, h = fieldHeight }
            local randomRect = { x = startX + fieldWidth + 12, y = fieldY, w = randomWidth, h = fieldHeight }

            if pointInRect(mouseX, mouseY, nameRect) then
                self.editing_display_name = true
            elseif pointInRect(mouseX, mouseY, randomRect) then
                SoundManager.play_sound("button_click")
                self.display_name_input = generateRandomDisplayName()
                Config.PLAYER_NAME = self.display_name_input
                self.editing_display_name = true
            else
                self.editing_display_name = false
            end
        end
    end

    -- Only process button clicks when dialog is NOT open
    if not self.ip_input_mode then
        if isDown and not self.mouseWasDown then
            self.activeButton = self.hoveredButton
        elseif not isDown and self.mouseWasDown then
            if self.activeButton ~= nil and self.hoveredButton == self.activeButton then
                local button = self.buttons[self.activeButton]
                if button and button.action then
                    SoundManager.play_sound("button_click")
                    button.action()
                end
            end

            self.activeButton = nil
        end

        if not isDown then
            self.activeButton = nil
        end
    end

    if self.hoveredButton and self.hoveredButton ~= prevHovered then
        SoundManager.play_sound("button_hover")
    end

    self.mouseWasDown = isDown
end

function MenuState:updateButtonLayout()
    if not self.buttons then
        return
    end

    self.buttonRects = self.buttonRects or {}
    for index = 1, #self.buttonRects do
        self.buttonRects[index] = nil
    end

    local sw, sh = love.graphics.getDimensions()

    local spacing = Theme.spacing
    local totalHeight = #self.buttons * spacing.buttonHeight + (#self.buttons - 1) * spacing.buttonSpacing
    local startX = (sw - spacing.buttonWidth) * 0.5
    local centerY = sh * 0.5 + spacing.menuVerticalOffset
    local startY = centerY - totalHeight * 0.5

    for index = 1, #self.buttons do
        local y = startY + (index - 1) * (spacing.buttonHeight + spacing.buttonSpacing)
        self.buttonRects[index] = {
            x = startX,
            y = y,
            w = spacing.buttonWidth,
            h = spacing.buttonHeight,
        }
    end
end

function MenuState:draw()
    local sw, sh = love.graphics.getDimensions()

    -- 1. Clear to a simple background color (pitch black)
    love.graphics.clear(0, 0, 0, 1)

    if self.background then
        love.graphics.push()
        love.graphics.origin()
        self.background:draw(0, 0, 0, 0)
        love.graphics.pop()
    end

    -- 2. Draw Title "NOVUS"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    if self.titleShader then
        love.graphics.setShader(self.titleShader)
    end
    love.graphics.printf("NOVUS", 0, sh * 0.08, sw, "center")
    love.graphics.setShader()

    self:updateButtonLayout()

    love.graphics.setFont(self.fontButton)
    local textHeight = self.fontButton:getHeight()

    for index, button in ipairs(self.buttons) do
        local rect = self.buttonRects[index]
        if rect then
            local hovered = self.hoveredButton == index

            local active = love.mouse.isDown(1) and self.activeButton == index

            local stateButton = "default"
            if active then
                stateButton = "active"
            elseif hovered then
                stateButton = "hover"
            end

            Theme.drawButton(rect.x, rect.y, rect.w, rect.h, button.label, stateButton, self.fontButton)
        end
    end

    -- Draw IP input dialog if active
    if self.ip_input_mode then
        drawModalOverlay(sw, sh)

        local layout = getJoinDialogLayout()
        local boxX = layout.boxX
        local boxWidth = layout.boxWidth
        local rounding = Theme.shapes.buttonRounding or 0

        local buttonColors = Theme.colors.button
        local textPrimary = Theme.colors.textPrimary
        local textMuted = Theme.colors.textMuted

        drawDialogBox(layout)

        -- Draw title
        love.graphics.setColor(textPrimary)
        love.graphics.setFont(self.fontButton)
        love.graphics.printf("Join Game", boxX, layout.titleY, boxWidth, "center")

        -- Draw IP label and field
        love.graphics.setColor(textMuted)
        love.graphics.printf("Server IP", boxX + 20, layout.ipLabelY, boxWidth - 40, "left")
        love.graphics.setColor(buttonColors.fill)
        love.graphics.rectangle("fill", layout.ipRect.x, layout.ipRect.y, layout.ipRect.w, layout.ipRect.h, rounding,
            rounding)
        if self.active_join_input == "ip" then
            love.graphics.setColor(buttonColors.outlineActive)
        else
            love.graphics.setColor(buttonColors.outline)
        end
        love.graphics.rectangle("line", layout.ipRect.x, layout.ipRect.y, layout.ipRect.w, layout.ipRect.h, rounding,
            rounding)

        -- Draw IP text
        love.graphics.setColor(textPrimary)
        local ipPadding = 10
        local ipTextX = layout.ipRect.x + ipPadding
        local ipTextY = layout.ipRect.y + (layout.ipRect.h - self.fontButton:getHeight()) * 0.5
        love.graphics.printf(self.ip_input, ipTextX, ipTextY, layout.ipRect.w - ipPadding * 2, "left")

        -- Draw blinking cursor in IP field
        if self.cursor_visible then
            love.graphics.setColor(buttonColors.outlineActive)
            local textWidth = self.fontButton:getWidth(self.ip_input)
            local caretHeight = self.fontButton:getHeight()
            love.graphics.rectangle("fill", ipTextX + textWidth + 2, ipTextY, 2, caretHeight)
        end

        -- Draw instructions
        love.graphics.setColor(textMuted)
        local smallFont = Theme.getFont("chat")
        love.graphics.setFont(smallFont)
        love.graphics.printf("Press ENTER to connect | ESC to cancel", boxX,
            layout.instructionsY, boxWidth, "center")
    end

    -- Persistent display name field at bottom center
    local sw2, sh2 = love.graphics.getDimensions()
    local fieldWidth, fieldHeight = 260, 40
    local randomWidth = 140
    local totalWidth = fieldWidth + 12 + randomWidth
    local startX = (sw2 - totalWidth) * 0.5
    local labelFont = self.fontButton
    local labelH = labelFont:getHeight()
    local bottomMargin = 60
    local fieldY = sh2 - bottomMargin - fieldHeight
    local labelY = fieldY - labelH - 6

    local bgColor = Theme.getBackgroundColor()
    local buttonColors = Theme.colors.button
    local textPrimary = Theme.colors.textPrimary
    local textMuted = Theme.colors.textMuted

    -- Label
    love.graphics.setFont(labelFont)
    love.graphics.setColor(textMuted)
    love.graphics.printf("Display Name", startX, labelY, totalWidth, "center")

    -- Name field
    local nameX = startX
    love.graphics.setColor(buttonColors.fill)
    love.graphics.rectangle("fill", nameX, fieldY, fieldWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)
    love.graphics.setColor(self.editing_display_name and buttonColors.outlineActive or buttonColors.outline)
    love.graphics.rectangle("line", nameX, fieldY, fieldWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)

    love.graphics.setColor(textPrimary)
    local nameText = self.display_name_input or ""
    local namePadding = 10
    local innerX = nameX + namePadding
    local innerWidth = fieldWidth - namePadding * 2
    local textWidth = self.fontButton:getWidth(nameText)
    local textX = innerX
    local textY = fieldY + (fieldHeight - self.fontButton:getHeight()) * 0.5
    love.graphics.printf(nameText, textX, textY, innerWidth, "left")

    -- Randomize button
    local randomX = startX + fieldWidth + 12
    Theme.drawButton(randomX, fieldY, randomWidth, fieldHeight, "Randomize", "default", self.fontButton)

    -- Caret in display name field
    if self.editing_display_name and self.cursor_visible then
        love.graphics.setColor(buttonColors.outlineActive)
        local caretHeight = self.fontButton:getHeight()
        love.graphics.rectangle("fill", textX + textWidth + 2, textY, 2, caretHeight)
    end

    if self.load_menu_open then
        drawModalOverlay(sw, sh)

        local layout = getLoadDialogLayout()
        local boxX = layout.boxX
        local boxWidth = layout.boxWidth
        local buttonColors2 = Theme.colors.button
        local textPrimary2 = Theme.colors.textPrimary

        drawDialogBox(layout)

        love.graphics.setColor(textPrimary2)
        love.graphics.setFont(self.fontButton)
        love.graphics.printf("Load Game", boxX, layout.titleY, boxWidth, "center")

        for slot, rect in ipairs(layout.slotRects) do
            local hasSave = SaveManager.has_save(slot)
            local label
            if hasSave then
                label = string.format("Slot %d - Continue", slot)
            else
                label = string.format("Slot %d - Empty", slot)
            end

            local hovered = (self.load_hovered_slot == slot) and hasSave
            local active = love.mouse.isDown(1) and self.load_active_slot == slot and hasSave
            local stateButton = "default"
            if active then
                stateButton = "active"
            elseif hovered then
                stateButton = "hover"
            end

            Theme.drawButton(rect.x, rect.y, rect.w, rect.h, label, stateButton, self.fontButton)
        end
    end

    if self.settings_open and SettingsPanel and SettingsPanel.draw then
        drawModalOverlay(sw, sh)
        SettingsPanel.draw()
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
    if self.settings_open then
        if key == "escape" then
            self.settings_open = false
            if SettingsPanel and SettingsPanel.reset then
                SettingsPanel.reset()
            end
        end
        return
    end

    if self.ip_input_mode then
        if key == "return" or key == "kpenter" then
            Gamestate.switch(require("src.states.play"), { mode = "join", host = self.ip_input })
        elseif key == "escape" then
            self.ip_input_mode = false
            self.ip_input = "localhost"
        elseif key == "backspace" then
            self.ip_input = string.sub(self.ip_input, 1, -2)
        end
        return
    end

    if self.editing_display_name then
        if key == "backspace" then
            self.display_name_input = string.sub(self.display_name_input, 1, -2)
            Config.PLAYER_NAME = self.display_name_input
        end
    end

    if key == 'escape' then
        if self.load_menu_open then
            self.load_menu_open = false
            self.load_hovered_slot = nil
            self.load_active_slot = nil
        else
            love.event.quit()
        end
        return
    end
end

function MenuState:textinput(t)
    if self.ip_input_mode then
        self.ip_input = self.ip_input .. t
        return
    end

    if self.editing_display_name then
        self.display_name_input = (self.display_name_input or "") .. t
        Config.PLAYER_NAME = self.display_name_input
    end
end

function MenuState:mousepressed(x, y, button, istouch, presses)
    if self.settings_open and SettingsPanel and SettingsPanel.mousepressed then
        local result = SettingsPanel.mousepressed(x, y, button)
        if result == "close" then
            self.settings_open = false
            if SettingsPanel.reset then
                SettingsPanel.reset()
            end
        end
        if result then
            return
        end
    end
end

return MenuState
