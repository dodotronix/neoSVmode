--
-- TODO add missing variables definitions 
-- TODO add configuration file to set: indent, extra libraries ...
-- TODO notifie the user, that not all stars were unfolded
-- TODO attache the fold and unfold functions to key shortcuts
-- TODO read setup table and upload the setings
--

local hierarchy = require('neoSVmode.parser.hierarchy')
local api = vim.api
local command = api.nvim_create_user_command

local M = {}

M.unfold = function ()
    local bufnr = api.nvim_get_current_buf()
    local m = hierarchy.from_buffer(bufnr)
    if m ~= nil then
        m:unfold_macros(bufnr)
    end
end

M.fold = function ()
    local bufnr = api.nvim_get_current_buf()
    local m = hierarchy.from_buffer(bufnr)
    if m ~= nil then
        m:fold_macros(bufnr)
    end
end

command('SVmodeFold', M.fold, {})
command('SVmodeUnfold', M.unfold, {})

return M
