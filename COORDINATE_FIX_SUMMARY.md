# Coordinate Conversion Fix - Summary of Changes

## Problem
Mouse cursor position didn't match actual in-game coordinates when:
1. Monitor resolution wasn't 1920x1080 (the reference resolution)
2. UI elements like the cargo window had hitbox misalignment
3. Turret aiming was offset from where the cursor appeared to be

## Root Cause
The game has a canvas (1920x1080) that gets scaled and positioned on the actual screen to maintain aspect ratio. At non-default resolutions, this canvas gets offset (letterboxing on ultrawide/ultratall monitors). The mouse coordinate conversions weren't accounting for this offset.

## Solution Implemented

### 1. Canvas Component Now Stores Actual Rendering Parameters
**File**: `src/systems/render.lua` (lines 320-323)

The render system now updates the Canvas component with the actual rendering parameters every frame:
```lua
canvasComp.offsetX = offsetX
canvasComp.offsetY = offsetY
canvasComp.scale = scale
```

These values are:
- `offsetX/Y`: Screen pixel position where the canvas starts (accounting for letterboxing)
- `scale`: How much the canvas is scaled to fit on screen

### 2. New Coordinate Conversion Function
**File**: `src/scaling.lua` (lines 61-78)

Added `Scaling.toUI(x, y)` function that converts screen coordinates to UI/reference space:
```lua
local uiX = (x - canvasComp.offsetX) / canvasComp.scale
local uiY = (y - canvasComp.offsetY) / canvasComp.scale
```

This properly accounts for:
- Canvas offset (letterboxing position)
- Canvas scale (how much it's zoomed)

### 3. Updated All UI Mouse Input Conversions
**File**: `src/systems/ui.lua`

Changed all mouse coordinate conversions from `Scaling.toGame()` to `Scaling.toUI()`:
- `UISystem.mousepressed(x, y, button)` - line 185
- `UISystem.mousereleased(x, y, button)` - line 211  
- `UISystem.mousemoved(x, y, dx, dy)` - line 219

**File**: `src/ui/window_base.lua`

Updated window base class for dragging support:
- `WindowBase:mousepressed()` - uses `Scaling.toUI()`
- `WindowBase:mousemoved()` - uses `Scaling.toUI()`

**File**: `src/ui/cargo_window.lua`

Updated cargo window UI hit testing:
- `CargoWindow:mousepressed()` - uses `Scaling.toUI()`
- `CargoWindow:mousereleased()` - uses `Scaling.toUI()`
- `CargoWindow:drawCloseButton()` - converts button rect to UI space (line 277)
- `CargoWindow:drawTurretPanel()` - converts slot rect to UI space (line 199-202)
- `CargoWindow:drawItemsGrid()` - converts item icons to UI space (line 313)

### 4. Consistent Size Conversion
All hotspot sizes are converted using:
```lua
uiSize = screenSize / Scaling.getScale()
```

This reverses the display scaling that was applied when the size was created.

## Key Insight & Best Practices
This approach uses a single authoritative internal reference space (1920x1080) and a separate screen-space canvas that is scaled and centered. It's a widely used, robust pattern for games and UI:

- Keep a consistent internal coordinate system (the reference size). UI layout and game logic can be authoring against this fixed size.
- Render the game to a 1920x1080 offscreen canvas and scale/letterbox it to the screen. This isolates resolution-dependent complexity to one place.
- Provide explicit, well-named conversion functions for the two common operations:
  - Screen → UI (reference): `Scaling.toUI(screenX, screenY)`
  - UI (reference) → Screen: `Scaling.toScreenCanvas(uiX, uiY)`
  - Screen → World: `Scaling.toWorld(screenX, screenY, cameraComp, cameraPos)`

This is simple, maintainable, and avoids subtle bugs that occur when mixing coordinate spaces directly. The scaling/transform values are cached and updated each frame for performance, and UI code uses a single conversion function to receive mouse coordinates in the correct space.

## Testing Recommendations
1. **Standard 16:9 resolutions**: 1920x1080, 2560x1440, 3840x2160
2. **Ultrawide**: 3440x1440 - tests horizontal letterboxing
3. **Ultratalll**: 1920x1200 - tests potential vertical changes
4. **Mismatched aspect**: Anything significantly different from 16:9

Expected behavior at all resolutions:
- ✅ Cargo window can be opened and closed
- ✅ Close button hitbox matches visual button
- ✅ Inventory items can be hovered and dragged
- ✅ Turret slot can receive dropped items
- ✅ Turret cursor/aim matches mouse position on screen
- ✅ Mining laser targets where cursor is visually pointing

## Files Modified
1. `src/systems/render.lua` - Store canvas rendering parameters
2. `src/scaling.lua` - Add `toUI()` conversion function
3. `src/systems/ui.lua` - Use `toUI()` for mouse input
4. `src/ui/window_base.lua` - Use `toUI()` for window dragging
5. `src/ui/cargo_window.lua` - Use `toUI()` for all UI hit testing

## Documentation
See `COORDINATE_CONVERSION.md` for detailed explanation of all coordinate systems and conversions.
