local uv = vim.loop
-- local a = require'plenary.async'
-- local Object = require "plenary.class"

M = {}

function M:new(opts)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local function onread(err, data)
        if err then
            print("error can't read data")
        end
        if data then
            local vals = vim.split(data, "\n")
            for _, d in pairs(vals) do
                if d == "" then goto continue end
                -- table.insert(self.results, d)
                ::continue::
            end
        end
    end

    self.handle =  uv.spawn("rg", {
        stdio = { nil, stdout, stderr},
        args = {"--files"}
    },
    function()
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        if not self.handle:is_closing() then
            self.handle:close()
        end
        -- P(self.results)
    end)

    uv.read_start(stdout, onread)
    uv.read_start(stderr, onread)


end

return M

