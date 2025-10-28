-- tests/main.lua
-- Love2D-compatible test entry point. When running `love .` from the repo root
-- this file will execute the test runner and quit.

function love.load()
    -- Ensure src/ is on package.path when running under love
    package.path = './src/?.lua;./src/?/init.lua;./?.lua;' .. package.path
    local ok, err = pcall(function() dofile('tests/run_tests.lua') end)
    if not ok then
        print('Test runner encountered an error: ' .. tostring(err))
    end
    -- Quit Love once tests complete
    love.event.quit()
end
