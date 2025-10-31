-- Test coordinate system across different resolutions
-- This file can be used to verify coordinate handling works correctly

local Scaling = require('src.scaling')

local function testCoordinateConversion()
    print("=== Coordinate System Test ===")
    
    -- Test different screen resolutions
    local testResolutions = {
        {1920, 1080},  -- Reference resolution
        {1366, 768},   -- Common laptop resolution
        {2560, 1440},  -- High DPI
        {1280, 720},   -- Lower resolution
        {3840, 2160}   -- 4K resolution
    }
    
    for _, res in ipairs(testResolutions) do
        local w, h = res[1], res[2]
        print(string.format("Testing resolution: %dx%d", w, h))
        
        -- Simulate mouse position at center of screen
        local centerX, centerY = w / 2, h / 2
        
        -- Test coordinate conversion
        local uiX, uiY = Scaling.toUI(centerX, centerY)
        local expectedX, expectedY = 1920 / 2, 1080 / 2  -- Should be center of reference resolution
        
        print(string.format("  Raw: (%.1f, %.1f) -> UI: (%.1f, %.1f) [Expected: (%.1f, %.1f)]", 
            centerX, centerY, uiX, uiY, expectedX, expectedY))
        
        -- Check if conversion is approximately correct (within 1 pixel tolerance)
        local tolerance = 1.0
        local xCorrect = math.abs(uiX - expectedX) < tolerance
        local yCorrect = math.abs(uiY - expectedY) < tolerance
        
        if xCorrect and yCorrect then
            print("  ✓ Coordinate conversion working correctly")
        else
            print("  ✗ Coordinate conversion issue detected")
        end
    end
end

-- Uncomment to run test
-- testCoordinateConversion()
