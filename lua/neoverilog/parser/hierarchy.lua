local api = vim.api
local ts_query = vim.treesitter.query
local Module = require("neoverilog.parser.module")
local LanguageTree = require('vim.treesitter.languagetree')
local Job = require('plenary.job').Job
local a = require('plenary.async')
local async, await = a.async, a.await

-- TODO maybe add a memoization module to store all the found paths 
-- and store the values in /tmp/ under unique number for a certain branch
-- local finder = require('neoverilog.finder')

local H = {}

function H:new(tree, content, str_content)
    local d = {tree = tree,
               content = content,
               modules = {},
               definitions = {},
               str_content = str_content}
    setmetatable(d, self)
    self.__index = self
    d:get_modules()
    return d
end

function H.from_buffer(bufnr)
    local content = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local str_content = table.concat(content, '\n')
    local trees = LanguageTree.new(str_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
        return H:new(trees[1], content, str_content)
    end
    return nil
end

function H:get_modules()
    local module_query = vim.treesitter.parse_query(
    "verilog", [[(module_declaration) @module]])

    for _, n in module_query:iter_captures(self.tree:root(), self.str_content) do
        local node_text = ts_query.get_node_text(n, self.str_content, false)
        local m = Module.from_str_content(node_text)
        table.insert(self.modules, m)
    end
end

function H:get_unique_names()
    local unique_ids = {}
    for _, m in ipairs(self.modules) do
        unique_ids = m:get_unique_names(unique_ids)
    end
    return unique_ids
end

local paths = {}

function H:find_definition_files()
    local unique_ids = self:get_unique_names()
    local pattern = "module\\s+" .. "clock_enable"
    -- TODO paralle search for paths of the instances in unique_ids

    --[[ -- for id, _ in pairs(unique_ids) do
        local tmp_job = Job:new({
            command = 'rg',
            args = {},
            cwd = '.',
            env = {},
            on_exit = function(j, _)
                table.insert(paths, j:result())
            end,
        })
        tmp_job:start() ]]
    -- end
    -- P(paths)
    -- TODO find each unique_id and get its path
end



function H:fill_portmaps()
    -- for i in modules:
    -- call every module:get_unfolded_instances
end

return H
