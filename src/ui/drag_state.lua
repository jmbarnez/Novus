---@diagnostic disable: undefined-global
-- Shared drag state for cross-window drag and drop

local DragState = {
    draggedItem = nil
}

function DragState.startDrag(itemData)
    DragState.draggedItem = itemData
end

function DragState.endDrag()
    DragState.draggedItem = nil
end

function DragState.getDragItem()
    return DragState.draggedItem
end

function DragState.hasDrag()
    return DragState.draggedItem ~= nil
end

return DragState

