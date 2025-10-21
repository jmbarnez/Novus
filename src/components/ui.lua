local Components = {}

-- UI component - User interface data
-- @field uiType string: Type of UI element
-- @field data table: UI-specific data
Components.UI = function(uiType, data)
    return {
        uiType = uiType or "hud",
        data = data or {}
    } -- Close the table definition properly
end

-- UI tag - Marks UI elements
Components.UITag = function()
    return {}
end

return Components
