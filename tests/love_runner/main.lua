-- tests/love_runner/main.lua
-- Love2D entry point used only for running tests via Love.
-- It sets up package.path to point at the repository src/ and then runs the test runner.

-- Make sure package.path includes the repo's src directory (one level up from this folder)
local repo_src = '../src/?.lua;../src/?/init.lua;'
package.path = repo_src .. package.path

-- Run the existing test runner
local ok, err = pcall(function() dofile('../run_tests.lua') end)
if not ok then
    print('Test runner failed: ' .. tostring(err))
end

-- Quit Love after tests complete
if love and love.event and love.event.quit then
    love.event.quit()
end
