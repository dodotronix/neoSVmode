local api = vim.api
local ts_query = vim.treesitter
local Module = require("neoverilog.parser.module")
local util = require('vim.lsp.util')
local LanguageTree = require('vim.treesitter.languagetree')

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
    local module_query = vim.treesitter.query.parse(
    "verilog", [[(module_declaration) @module]])

    for _, n in module_query:iter_captures(self.tree:root(), self.str_content) do
        local node_text = ts_query.get_node_text(n, self.str_content, false)
        local range = { n:range() }
        -- start/stop row, start/stop column
        local start_offset = {range[1], range[2]}
        local end_offset = {range[3], range[4]}
        local m = Module.from_str_content(node_text, start_offset, end_offset)
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

function H:find_definition_files()

    local make_position_param = function (position)
        return {
            textDocument = util.make_text_document_params(),
            position = position
        }
    end

    local unique_ids = self:get_unique_names()
    for i, p in pairs(unique_ids) do
        local res, err = vim.lsp.buf_request_sync(
        0, "textDocument/definition", make_position_param(p))
        unique_ids[i] = res[1]
    end

    P(unique_ids)
    -- rg -l -U --multiline-dotall -g '*.sv' -e "module\\s+clock_enable" .
    -- TODO parsing and creating the port maps
end



function H:fill_portmaps()
    -- for i in modules:
    -- call every module:get_unfolded_instances
end

return H
