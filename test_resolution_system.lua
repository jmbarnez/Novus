-- Test script to verify dynamic resolution system
-- This can be run to test that resolution changes work correctly

local Constants = require('src.constants')
local Scaling = require('src.scaling')

print("=== Testing Dynamic Resolution System ===")

-- Test getting current resolution
print("Current window resolution:")
local w, h = Constants.getScreenWidth(), Constants.getScreenHeight()
print(string.format("  Constants.getScreenWidth(): %d", w))
print(string.format("  Constants.getScreenHeight(): %d", h))

-- Test scaling system
print("\nScaling system:")
print(string.format("  REFERENCE_WIDTH: %d", Scaling.REFERENCE_WIDTH))
print(string.format("  REFERENCE_HEIGHT: %d", Scaling.REFERENCE_HEIGHT))
print(string.format("  windowWidth: %d", Scaling.windowWidth))
print(string.format("  windowHeight: %d", Scaling.windowHeight))

-- Test scaling functions
print("\nScaling functions:")
local scaleX, scaleY = Scaling.getScale()
print(string.format("  Scaling.getScale(): %.3f, %.3f", scaleX, scaleY))

local scaledSize = Scaling.scaleSize(100)
print(string.format("  Scaling.scaleSize(100): %.1f", scaledSize))

local scaledX = Scaling.scaleX(500)
local scaledY = Scaling.scaleY(300)
print(string.format("  Scaling.scaleX(500): %.1f", scaledX))
print(string.format("  Scaling.scaleY(300): %.1f", scaledY))

-- Test conversion functions
print("\nConversion functions:")
local screenX, screenY = Scaling.toScreen(100, 100)
print(string.format("  Scaling.toScreen(100, 100): %.1f, %.1f", screenX, screenY))

local gameX, gameY = Scaling.toGame(200, 200)
print(string.format("  Scaling.toGame(200, 200): %.1f, %.1f", gameX, gameY))

print("\n=== Resolution System Test Complete ===")
