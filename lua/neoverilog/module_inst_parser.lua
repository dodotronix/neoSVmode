--

local api = vim.api
local command = api.nvim_create_user_command

M = {}

M.get_instance_table = function ()
   print("instance_table")
end

command('NeoVinst', M.get_instance_table, {})

return M
