# Coordinate System Documentation

## Overview
The game uses multiple coordinate systems that need to be properly converted:

### 1. Reference/UI Space (1920x1080)
- **What**: Internal game coordinates, base resolution
- **Used for**: All UI element positions, game logic
- **Range**: 0-1920 (X), 0-1080 (Y)
- **Where it's stored**: `self.position.x/y` in UI elements, world coordinates

### 2. Screen Space
- **What**: Actual monitor/window pixel coordinates
- **Used for**: LÖVE input callbacks (mouse positions)
- **Range**: 0 to monitor resolution (e.g., 2560x1440, 3840x2160, etc.)
- **Variable**: Changes based on monitor resolution

### 3. Canvas Space
- **What**: Rendered game canvas before scaling to screen
- **Size**: Always 1920x1080 (same as reference space)
- **Used for**: Internal rendering target
- **Note**: For coordinate purposes, canvas space = reference space

## Coordinate Conversions

### Display Scaling (`Scaling.getScale()`)
- Ratio: screen size / reference size
- With `maintainAspect = true`: `min(scaleX, scaleY)` to prevent stretching
- Used by: `Scaling.scaleX/Y/Size()` functions

### Canvas Scaling (stored in Canvas component)
- `canvasComp.offsetX/Y`: Where the canvas is positioned on screen (accounting for letterbox)
- `canvasComp.scale`: How much the canvas is scaled to fit on screen
- Calculated in `render.lua` line 316-319
- Formula:
  ```
  scaleX = screenWidth / canvasWidth (1920)
  scaleY = screenHeight / canvasHeight (1080)
  scale = min(scaleX, scaleY)  -- due to maintainAspect
  offsetX = (screenWidth - canvasWidth * scale) / 2
  offsetY = (screenHeight - canvasHeight * scale) / 2
  ```

## Important Insight
The display scaling (`Scaling.getScale()`) and canvas scaling (`canvasComp.scale`) are actually the SAME value! Both calculate `min(scaleX, scaleY)`.

## Conversion Functions

### `Scaling.scaleX/Y/Size(refCoord)` - Reference → Screen
```lua
screenCoord = refCoord * Scaling.getScale()
```
Used when: Drawing UI elements (they're stored in reference space, need to draw in screen space)

### `Scaling.toGame(screenCoord)` - Screen → Reference (ignoring offset)
```lua
refCoord = screenCoord / Scaling.getScale()
```
Used when: Simple scaling without considering canvas offset (works for non-letterboxed cases)

### `Scaling.toUI(screenCoord)` - Screen → Reference (including offset)
```lua
refCoord = (screenCoord - canvasComp.offsetX) / canvasComp.scale
```
Used when: Converting mouse coordinates for UI hit testing (accounts for letterboxing)

## Problem Scenario
When monitor has different aspect ratio than 16:9 (e.g., ultrawide 21:9):
- Canvas gets letterboxed (black bars on sides or top/bottom)
- `offsetX/Y` > 0 to center the canvas
- Mouse clicks in the black area would give invalid reference coordinates
- This is CORRECT behavior - clicks outside the game window shouldn't hit UI

## Current Issues & Fixes
1. ✅ Canvas offset/scale now updated every frame in `render.lua`
2. ✅ UI system now uses `Scaling.toUI()` for all mouse coordinate conversions
3. ✅ Mouse hitting close button, items, etc. should now be correct

## Testing Recommendations
1. Test at default 16:9 resolutions (1920x1080, 2560x1440, 3840x2160)
2. Test at ultrawide (3440x1440 or similar) - should have horizontal letterbox
3. Test at ultraviolet (1920x1200) - should work fine
4. Verify mouse clicks align with visual elements at all resolutions
