# Universal Plasma/Energy Graphics Style

## Overview

The plasma/energy-style graphics have been applied universally across the entire rendering pipeline, ensuring consistent visual style throughout the game.

## Universal Enhancements

### 1. Cel-Shading Shader
Applied as post-processing effect on the entire canvas:
- **Color Quantization**: 2.5 steps for distinct color bands
- **Saturation Boost**: 1.6x for vibrant energy colors
- **Enhanced Contrast**: 0.85 gamma for stronger shadows
- **Highlight Boost**: 20% brightness increase
- **Edge Detection**: Automatic black outline generation

### 2. Dark Navy Blue Background
- Space backdrop uses **dark navy blue `(0.02, 0.02, 0.1)`**
- Darker than original but not pure black for better depth perception
- Excellent contrast for all colored elements
- Enhanced visibility of all game objects

### 3. Enhanced Outlines (Universal)
All shapes now use plasma-style thick black outlines:
- **Polygons**: 4px + 2px dual-layer outline
- **Circles**: 3px outline
- **Rectangles**: 3px outline
- **Turrets**: 3px outline
- **Lasers**: 6px outline (80% opacity)

### 4. Universal Health Bars
All health bars use the new `PlasmaTheme` system:
- **Thick 3px black outlines**
- **Vibrant plasma colors**: Electric pink/magenta (1, 0.2, 0.5) for hull, bright cyan (0.2, 0.8, 1) for shields
- **Consistent styling** across all enemy health bars, player HUD, and targeting panels

### 5. Enhanced Durability Bars
Asteroid and wreckage durability bars:
- **Asteroid bars**: Vibrant solid yellow (1, 0.9, 0) fill with thick outline
- **Wreckage bars**: Bright mint green energy (0.1, 1, 0.8) fill with thick outline
- **Consistent 3px black outlines** for maximum definition

### 6. Brighter Stars
Starfield rendering enhanced:
- **Static stars**: 50% brighter with circle rendering
- **Parallax stars**: 30% brighter with circle rendering
- Better visibility against pure black background

## Plasma Theme Module

A new `src/ui/plasma_theme.lua` module provides:

### Unified Color Palette
```lua
-- Pure black background
bgPureBlack = {0, 0, 0, 1}

-- Health bar colors
healthBarFill = {1, 0.2, 0.5, 1}  -- Electric pink/magenta
shieldBarFill = {0.2, 0.8, 1, 1}  -- Bright cyan

-- Durability bar colors
asteroidBarFill = {1, 0.9, 0, 1}  -- Vibrant solid yellow
wreckageBarFill = {0.1, 1, 0.8, 1}  -- Bright mint green energy

-- Outline settings
outlineThick = 3
outlineVeryThick = 4
```

### Helper Functions
- `PlasmaTheme.drawHealthBar()` - Draws health/shield bars with consistent styling
- `PlasmaTheme.drawDurabilityBar()` - Draws asteroid/wreckage durability bars

## Files Modified

### Core Rendering
- `src/systems/render.lua` - All rendering uses plasma theme
- `src/shaders/cel_shader.frag` - Enhanced cel-shading effect
- `src/shader_manager.lua` - Updated shader properties
- `src/parallax.lua` - Brighter star rendering

### UI Systems
- `src/systems/hud.lua` - HUD health bars use plasma theme
-- `src/ui/plasma_theme.lua` - New universal theme module
-- `src/ui/plasma_theme.lua` - Updated with plasma color palette (legacy `theme.lua` removed)

## Visual Consistency

All game elements now share:
1. **Thick black outlines** (3-4px)
2. **Vibrant, electric colors** (cyans, blues, purples, pink)
3. **High contrast** against pure black background
4. **Cel-shaded appearance** with quantized colors
5. **Sci-fi energy aesthetic** throughout

## Controls

- **F11**: Toggle cel-shading on/off (to compare visual impact)

## Performance

The universal plasma styling has minimal performance impact:
- Cel-shading runs as single-pass post-processing effect
- GPU-accelerated shader rendering
- No additional draw calls (outlines rendered inline)
- Efficient theme module with reusable helpers

## Customization

To adjust the plasma intensity:

```lua
-- In src/shader_manager.lua
ShaderManager.setCelShadingProperties({
    colorSteps = 2.5,    -- Lower = more pronounced (try 2-5)
    saturation = 1.6     -- Higher = more vibrant (try 1.0-2.0)
})
```

All visual elements will automatically adapt to these settings through the universal theme system.

