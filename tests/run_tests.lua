-- tests/run_tests.lua
-- Simple test runner for the project's Lua tests.
-- Usage: `lua tests/run_tests.lua` from the repository root.

-- Ensure the project's `src/` directory is on package.path so `require('src.xxx')` works.
package.path = './src/?.lua;./src/?/init.lua;./?.lua;' .. package.path

local function list_test_files()
    local files = {}
    -- Prefer a portable Lua listing when available
    local p = io.popen('dir /b tests 2>nul') -- Windows-friendly
    if not p then
        p = io.popen('ls tests 2> /dev/null')
    end
    if not p then
        error('Could not list tests directory')
    end
    for name in p:lines() do
        if name:match('%.lua$') and name ~= 'run_tests.lua' and name ~= 'main.lua' then
            table.insert(files, name)
        end
    end
    p:close()
    table.sort(files)
    return files
end

local tests = list_test_files()
if #tests == 0 then
    print('No test files found in tests/')
    os.exit(0)
end

for _, file in ipairs(tests) do
    print(string.format('\n== Running: %s ==', file))
    local ok, err = pcall(function() dofile('tests/' .. file) end)
    if not ok then
        io.stderr:write('Test failed: ' .. tostring(err) .. '\n')
        os.exit(1)
    end
end

print('\nAll tests passed')
