local Theme = require "src.ui.theme"
local SoundManager = require "src.managers.sound_manager"
local utf8 = require "utf8"
local spacing = Theme.spacing

local Chat = {
    active = false,
    enabled = false,
    lines = {},
    inputBuffer = "",
    maxLines = 50,
    
    -- Layout
    x = spacing.chatMarginX or 20,
    width = spacing.chatWidth or 600,
    height = spacing.chatHeight or 300,
    
    colors = Theme.colors.chat,

    -- Tabs
    activeTab = "chat",
    tabs = { "chat", "system", "all" },
    tabHeight = 20,
    tabLabels = {
        chat = "Chat",
        system = "System",
        all = "All",
    },

    -- Unread system messages (for badge on System tab)
    unreadSystem = 0,

    -- Unread chat messages (for badge on Chat tab)
    unreadChat = 0,
    _hoveredTab = nil,
}

local function isSystemType(t)
    return t == "system" or t == "error" or t == "debug"
end

local function isVisibleInTab(messageType, tab)
    if tab == "chat" then
        return messageType == nil or messageType == "text"
    elseif tab == "system" then
        return isSystemType(messageType)
    elseif tab == "all" then
        return true
    end
    return true
end

function Chat.init()
    Chat.font = Theme.getFont("chat")
    Chat.lineHeight = Chat.font:getHeight() + 4
    Chat.unreadSystem = 0
    Chat.unreadChat = 0
    
    -- Initial welcome message
    Chat.addMessage("Welcome to NovusMP!", "system")
    Chat.addMessage("Press Enter to chat.", "system")
    Chat.unreadSystem = 0
end

function Chat.addMessage(text, type, timestamp)
    type = type or "text"
    local color = Chat.colors[type] or Chat.colors.text
    
    table.insert(Chat.lines, {
        text = text,
        messageType = type,
        color = color,
        timestamp = timestamp or os.time()
    })
    
    if isSystemType(type) and Chat.activeTab == "chat" then
        Chat.unreadSystem = (Chat.unreadSystem or 0) + 1
    end

    if type == "text" and Chat.activeTab ~= "chat" then
        Chat.unreadChat = (Chat.unreadChat or 0) + 1
    end

    if #Chat.lines > Chat.maxLines then
        table.remove(Chat.lines, 1)
    end
end

-- Helper functions
function Chat.print(text) Chat.addMessage(tostring(text), "text") end
function Chat.system(text) Chat.addMessage(tostring(text), "system") end
function Chat.error(text) Chat.addMessage(tostring(text), "error") end
function Chat.debug(text) Chat.addMessage(tostring(text), "debug") end

function Chat.setSendHandler(fn)
    Chat.sendHandler = fn
end

function Chat.enable()
    Chat.enabled = true
end

function Chat.disable()
    Chat.enabled = false
    Chat.active = false
    Chat.inputBuffer = ""
end

function Chat.isEnabled()
    return Chat.enabled
end

-- New helper to check if chat is currently focused/typing
function Chat.isActive()
    return Chat.active
end

function Chat.update(dt)
    if not Chat.enabled then return end
    -- Logic for fading or scrolling could go here
end

function Chat.draw()
    if not Chat.enabled then return end

    local screenH = love.graphics.getHeight()
    local bottom = screenH - 20
    
    -- If active, shift up to make room for input box
    local inputHeight = Theme.spacing.chatInputHeight or 30
    
    local listBottom = bottom - (Chat.active and inputHeight or 0)
    
    love.graphics.setFont(Chat.font)

    local tabHeight = Chat.tabHeight or 20
    local messagesHeight = Chat.height - tabHeight
    if messagesHeight < Chat.lineHeight then
        messagesHeight = Chat.lineHeight
    end

    local messagesBottom = listBottom - tabHeight
    local activeTab = Chat.activeTab or "chat"

    -- Draw messages (bottom-up)
    local count = 0
    for i = #Chat.lines, 1, -1 do
        local line = Chat.lines[i]
        if isVisibleInTab(line.messageType, activeTab) then
            local y = messagesBottom - (count + 1) * Chat.lineHeight
            
            -- Stop if we go above the allowed height
            if messagesBottom - y > messagesHeight then break end
            
            local timePrefix = ""
            if line.timestamp then
                timePrefix = tostring(os.date("[%H:%M] ", line.timestamp))
            end
            local fullText = timePrefix .. line.text
            
            -- Text shadow for readability
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.print(fullText, Chat.x + 1, y + 1)
            
            love.graphics.setColor(line.color)
            love.graphics.print(fullText, Chat.x, y)
            
            count = count + 1
        end
    end

    -- Draw tab bar
    local font = Chat.font
    local paddingX = 8
    local paddingY = 0
    
    local tabY = messagesBottom
    local tabX = Chat.x
    Chat._tabRects = {}

    local mx, my = love.mouse.getPosition()

    local hoveredTabId
    for _, tabId in ipairs(Chat.tabs) do
        local label = Chat.tabLabels[tabId] or tabId
        if tabId == "system" and Chat.unreadSystem and Chat.unreadSystem > 0 then
            label = label .. " (" .. tostring(Chat.unreadSystem) .. ")"
        end
        if tabId == "chat" and Chat.unreadChat and Chat.unreadChat > 0 then
            label = label .. " (" .. tostring(Chat.unreadChat) .. ")"
        end
        local textW = font:getWidth(label)
        
        local w = textW + paddingX * 2
        local h = tabHeight
        local isActive = (activeTab == tabId)

        local hovered = (mx >= tabX and mx <= tabX + w and my >= tabY and my <= tabY + h)

        local state = "default"
        if isActive then
            state = "active"
        elseif hovered then
            state = "hover"
        end

        Theme.drawButton(tabX, tabY, w, h, label, state, font)

        Chat._tabRects[#Chat._tabRects + 1] = { id = tabId, x = tabX, y = tabY, w = w, h = h }

        if hovered then
            hoveredTabId = tabId
        end

        tabX = tabX + w + 6
    end

    local prevHovered = Chat._hoveredTab
    Chat._hoveredTab = hoveredTabId
    if hoveredTabId and hoveredTabId ~= prevHovered then
        SoundManager.play_sound("button_hover")
    end
    
    -- Draw input box if active
    if Chat.active then
        local inputY = bottom - inputHeight + 5
        
        love.graphics.setColor(Chat.colors.inputBackground)
        love.graphics.rectangle("fill", Chat.x, inputY, Chat.width, inputHeight - 5)
        
        love.graphics.setColor(Theme.colors.button.outline)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", Chat.x, inputY, Chat.width, inputHeight - 5)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("> " .. Chat.inputBuffer .. "|", Chat.x + 5, inputY + 2)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function Chat.mousepressed(x, y, button)
    if not Chat.enabled or button ~= 1 or not Chat._tabRects then
        return false
    end

    for _, rect in ipairs(Chat._tabRects) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            SoundManager.play_sound("button_click")
            if Chat.activeTab ~= rect.id then
                Chat.activeTab = rect.id
                if rect.id == "system" or rect.id == "all" then
                    Chat.unreadSystem = 0
                end
                if rect.id == "chat" or rect.id == "all" then
                    Chat.unreadChat = 0
                end
            end
            return true
        end
    end

    return false
end

function Chat.keypressed(key)
    if not Chat.enabled then
        return false
    end

    -- Open chat with Enter when inactive
    if (key == "return" or key == "kpenter") and not Chat.active then
        Chat.active = true
        love.keyboard.setKeyRepeat(true)
        return true -- Consume the key so it doesn't trigger other actions
    end

    if Chat.active then
        if key == "return" or key == "kpenter" then
            -- Send message
            if #Chat.inputBuffer > 0 then
                local message = Chat.inputBuffer
                Chat.inputBuffer = ""
                if Chat.sendHandler then
                    Chat.sendHandler(message)
                else
                    Chat.addMessage("You: " .. message, "text")
                end
            end
            Chat.active = false
            love.keyboard.setKeyRepeat(false)
            return true
        elseif key == "escape" then
            Chat.active = false
            love.keyboard.setKeyRepeat(false)
            return true
        elseif key == "backspace" then
            local byteoffset = utf8.offset(Chat.inputBuffer, -1)
            if byteoffset then
                Chat.inputBuffer = string.sub(Chat.inputBuffer, 1, byteoffset - 1)
            end
            return true
        end
        
        -- Consume all keys when chat is active so they don't trigger ship controls
        return true
    end
    
    return false
end

function Chat.textinput(t)
    if not Chat.enabled then
        return false
    end

    if Chat.active then
        Chat.inputBuffer = Chat.inputBuffer .. t
        return true -- Consume input
    end
    return false
end

return Chat