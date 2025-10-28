-- tests/run_tests.lua
-- Simple test runner for the project's Lua tests.
-- Usage: `lua tests/run_tests.lua` from the repository root.

-- Ensure the project's `src/` directory is on package.path so `require('src.xxx')` works.
package.path = './src/?.lua;./src/?/init.lua;./?.lua;' .. package.path

-- Collect test files in a cross-platform way. If a single filename is passed
-- as the first CLI arg, run just that test.
local function list_test_files(single_file)
    local files = {}

    if single_file and single_file:match('%.lua$') then
        -- run single test only (assume it lives under tests/)
        table.insert(files, single_file)
        return files
    end

    -- Try platform commands first
    local p = io.popen('dir /b tests 2>nul') -- Windows-friendly
    if not p then
        p = io.popen('ls tests 2> /dev/null')
    end

    if p then
        for name in p:lines() do
            if name:match('%.lua$') and name ~= 'run_tests.lua' and name ~= 'main.lua' then
                table.insert(files, name)
            end
        end
        p:close()
        table.sort(files)
        return files
    end

    -- Fallback: use LuaFileSystem if available
    local ok, lfs = pcall(require, 'lfs')
    if ok and lfs then
        for name in lfs.dir('tests') do
            if name:match('%.lua$') and name ~= 'run_tests.lua' and name ~= 'main.lua' then
                table.insert(files, name)
            end
        end
        table.sort(files)
        return files
    end

    error('Could not list tests directory; install LuaFileSystem or ensure `ls`/`dir` is available')
end

local tests = list_test_files(arg and arg[1])
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
