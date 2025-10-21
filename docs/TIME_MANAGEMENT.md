# Time Management System

## Overview

The game uses a **fixed timestep** pattern to decouple game logic updates from rendering. This provides several benefits:

- **Deterministic gameplay**: Physics and game logic update at a consistent rate
- **Frame-rate independent**: Gameplay feels the same regardless of FPS
- **Multicore ready**: Update and render can potentially run on separate threads
- **Configurable FPS**: Easy to add FPS caps or unlock frame rate

## Architecture

### Fixed Timestep Pattern

```
Game Loop:
1. Accumulate frame time (dt)
2. Update game logic in fixed steps (60 Hz)
3. Render as fast as possible (or capped)
```

### Components

- **TimeManager** (`src/time_manager.lua`): Manages fixed timestep logic
- **main.lua**: Game loop that uses TimeManager
- **Core**: Game logic updates with fixed dt

## Configuration

### Current Settings

- **Update Rate**: 60 Hz (1/60 = 0.0166... seconds per update)
- **Target FPS**: Unlocked (nil) - to measure maximum performance
- **VSync**: Disabled
- **Max Frame Time**: 0.25 seconds (prevents spiral of death)

### Changing Settings

#### Set Fixed Update Rate

```lua
-- In main.lua or anywhere after TimeManager is loaded
TimeManager.setUpdateRate(120)  -- 120 updates per second
```

#### Set Target FPS

```lua
-- Unlimited FPS (current setting)
TimeManager.setTargetFps(nil)

-- Cap at 60 FPS
TimeManager.setTargetFps(60)

-- Cap at 144 FPS
TimeManager.setTargetFps(144)
```

#### Enable VSync

```lua
-- VSync is automatically managed by setTargetFps
-- Manual override:
love.window.setVSync(1)  -- Enable
love.window.setVSync(0)  -- Disable
```

## Usage Examples

### Getting FPS

```lua
local currentFps = TimeManager.getFps()
print("Current FPS:", currentFps)
```

### Getting Fixed Delta Time

```lua
local fixedDt = TimeManager.getFixedDt()
-- Use this for consistent physics calculations
```

### Getting Interpolation Alpha

```lua
local alpha = TimeManager.getAlpha()
-- Use for smooth interpolation between updates (0.0 to 1.0)
-- Example: render position = prevPos + (currentPos - prevPos) * alpha
```

## Future Enhancements

### Interpolation

To make rendering ultra-smooth, implement position interpolation:

```lua
-- In physics components, store previous position
component.prevX = component.x
component.prevY = component.y

-- In render system, interpolate
local alpha = TimeManager.getAlpha()
local renderX = prevX + (currentX - prevX) * alpha
local renderY = prevY + (currentY - prevY) * alpha
```

### Multicore Processing

The fixed timestep allows for potential multicore optimization:

1. **Thread 1**: Game logic updates (physics, AI, etc.)
2. **Thread 2**: Rendering (using interpolated positions)

Love2D's threading system can be used for this in the future.

### FPS Limiting

Add user-configurable FPS limits in settings:

```lua
-- In settings menu
local fpsCaps = {30, 60, 120, 144, nil} -- nil = unlimited
TimeManager.setTargetFps(selectedCap)
```

## Performance Monitoring

### HUD Display

The FPS counter is displayed in the top-right corner:
- **Cyan**: Unlocked FPS mode
- **Green**: Meeting target FPS (>95%)
- **Yellow**: Struggling (70-95% of target)
- **Red**: Below target (<70%)

### Console Monitoring

```lua
-- Add to any system for debugging
print("FPS:", TimeManager.getFps())
print("Fixed DT:", TimeManager.getFixedDt())
print("Alpha:", TimeManager.getAlpha())
```

## Implementation Details

### Accumulator Pattern

The TimeManager uses an accumulator to handle variable frame times:

```lua
accumulator = accumulator + dt

while accumulator >= fixedDt do
    -- Update game logic
    Core.update(fixedDt)
    accumulator = accumulator - fixedDt
end

-- Interpolation alpha for rendering
alpha = accumulator / fixedDt
```

### Spiral of Death Prevention

If a frame takes too long (> 0.25s), we clamp it to prevent the game from freezing:

```lua
dt = math.min(dt, maxFrameTime)
```

This prevents the accumulator from growing indefinitely during lag spikes.

## Testing

### Measure Maximum FPS

Current configuration (unlocked FPS) allows measuring peak performance:

1. Run the game
2. Check FPS counter in top-right
3. Note average FPS during normal gameplay
4. Note FPS during intensive scenarios (many entities, combat, etc.)

### Test Different Caps

```lua
-- In main.lua, change:
TimeManager.setTargetFps(60)   -- Test 60 FPS cap
TimeManager.setTargetFps(120)  -- Test 120 FPS cap
TimeManager.setTargetFps(nil)  -- Test unlimited
```

## Recommendations

1. **Development**: Keep FPS unlocked to identify performance bottlenecks
2. **Release**: Default to 60 FPS with option to unlock
3. **High-end**: Offer 120/144 FPS options for gaming monitors
4. **Low-end**: Offer 30 FPS cap to maintain smooth gameplay on weak hardware

## References

- [Fix Your Timestep](https://gafferongames.com/post/fix_your_timestep/)
- [Game Programming Patterns - Game Loop](https://gameprogrammingpatterns.com/game-loop.html)

