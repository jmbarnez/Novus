# Plasma/Energy Graphics

## Overview

The game now features plasma/energy-style cel-shaded graphics with bold outlines, vibrant electric colors, and a sci-fi energy aesthetic.

## Features

### Cel-Shading Shader
- **Color Quantization**: Reduces color gradients to distinct bands (2.5 steps for strong plasma look)
- **Enhanced Saturation**: Boosts color vibrancy (1.6x) for that bold energy feel
- **Enhanced Contrast**: More aggressive contrast (0.85 gamma) for stronger shadows
- **Highlight Boost**: Brightens highlights by 20% for more dramatic effect
- **Edge Detection**: Automatically detects and outlines edges in black

### Enhanced Outlines
- **Polygons**: Dual-layer black outlines (4px + 2px) for strong definition
- **Circles**: 3px black outlines
- **Rectangles**: 3px black outlines  
- **Turrets**: 3px black outlines
- **Lasers**: 6px black outline with 80% opacity for definition

### Visual Style
- **Dark Navy Blue Background**: Deep space uses dark navy blue (0.02, 0.02, 0.1) for depth and contrast
- **Brighter Stars**: Stars are 30-50% brighter and rendered as circles instead of points
- **Bold, Vibrant Colors**: Electric blues, cyans, purples, and energy colors throughout
- **Hard Shadows**: Minimal gradients with aggressive quantization
- **Sci-Fi Energy Aesthetic**: Strong outlines and high contrast throughout
- **Distinct Visual Separation**: Every object clearly defined with black outlines

## Controls

- **F11**: Toggle cel-shading on/off (to compare with/without the effect)

## Technical Details

### Shader System
The cel-shading is implemented as a post-processing shader that:
1. Detects edges via alpha difference
2. Applies black outlines to detected edges
3. Quantizes colors into distinct bands
4. Enhances saturation for vibrant colors
5. Applies slight contrast enhancement

### File Structure
- `src/shaders/cel_shader.frag` - Fragment shader for cel-shading
- `src/shaders/cel_shader.vert` - Vertex shader (minimal pass-through)
- `src/shader_manager.lua` - Manages shader loading and properties
- `src/systems/render.lua` - Applies shader during rendering

### Performance
The cel-shading effect has minimal performance impact as it runs as a single-pass post-processing effect on the final canvas. The shader is GPU-accelerated and works on all graphics cards that support GLSL shaders.

## Customization

To adjust the plasma effect, modify `src/shader_manager.lua`:

```lua
ShaderManager.setCelShadingProperties({
    colorSteps = 2.5,    -- Lower = more pronounced bands (try 2-5)
    saturation = 1.6     -- Higher = more vibrant colors (try 1.0-2.0)
})
```

The outline thickness is controlled programmatically in the render system, not through shader uniforms.

## Disabling the Effect

The cel-shading can be completely disabled by:
1. Pressing F11 to toggle off
2. Or modifying `src/shader_manager.lua` to set `useCelShading = false`

## Credits

Plasma/energy-style graphics implementation inspired by sci-fi visual aesthetics.

