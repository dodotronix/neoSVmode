--
-- TODO test if interfaces are added to portmaps
-- TODO add missing variables definitions 
-- TODO load it as git package to nvim
-- TODO rewrite the code to be better organized
-- TODO check for the library definitions
--
-- TODO add configuration file to set: indent, extra libraries ...
-- TODO notifie the user, that not all stars were unfolded
-- TODO attache the fold and unfold functions to key shortcuts
-- TODO read setup table and upload the setings
--
-- TODO first find all the instances in the current file
--

local hierarchy = require('neoverilog.parser.hierarchy')
local api = vim.api
local command = api.nvim_create_user_command

local M = {}

M.node_test = function ()
    local bufnr = api.nvim_get_current_buf()
    local m = hierarchy.from_buffer(bufnr)
    if m ~= nil then
        m:unfold_macros()
    end
end

command('Vtest', M.node_test, {})

return M
