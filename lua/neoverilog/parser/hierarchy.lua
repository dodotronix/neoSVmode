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

    local parse_definition = function (content)
        local res = {}
        local trees = LanguageTree.new(content, 'verilog', {})
        trees = trees:parse()
        if #trees > 0 then
            local param_query = [[
            (parameter_declaration (data_type_or_implicit1) @datatype
            (list_of_param_assignments (_ (parameter_identifier) @name
            (constant_param_expression) @value))) @param
           ]]

            local port_query = [[
            ((ansi_port_declaration ( variable_port_header 
            (port_direction) @direction
            (data_type) @datatype)
            (port_identifier) @name)) @port
            ]]

            local interface_query = [[
            (ansi_port_declaration (interface_port_header 
            (interface_identifier) @id
            (modport_identifier) @modport)
            (port_identifier) @name) @iface
            ]]

            -- TODO nonansi definitions parser
            local nonansi_port = [[ (module_nonansi_header) @test ]]

            local parsers = {}
            parsers.param = vim.treesitter.query.parse("verilog", param_query)
            parsers.port = vim.treesitter.query.parse("verilog", port_query)
            parsers.iface = vim.treesitter.query.parse("verilog", interface_query)

            for name, p in pairs(parsers) do
                local parsed = {}
                for a, n in p:iter_captures(trees[1]:root(), content) do
                    local group = p.captures[a]
                    -- next param, port, iface definition
                    -- create new empty list to store the
                    -- parsed values from the TS query
                    if parsers[group] ~= nil then
                        table.insert(parsed, 1, {})
                    else
                        parsed[1][group] = ts_query.get_node_text(n, content)
                    end
                end
                res[name] = parsed
            end
        end
        return res
    end

    local unique_ids = self:get_unique_names()
    for i, p in pairs(unique_ids) do
        local res, err = vim.lsp.buf_request_sync(
        0, "textDocument/definition", make_position_param(p))
        local result = res[1].result[1]

        if result ~= nil then
            local path = vim.uri_to_fname(result.uri)
            local content = vim.fn.readfile(path)
            local file_content = vim.fn.join(content, "\n")
            unique_ids[i] = path

            local trees = LanguageTree.new(file_content, 'verilog', {})
            trees = trees:parse()
            if #trees > 0 then
                local pattern = "(module_declaration (module_header) @m (#match? @m module " .. i  .. ")) @module"

                local def_query = vim.treesitter.query.parse("verilog", pattern)

                for a, n in def_query:iter_captures(trees[1]:root(), file_content) do
                    local group = def_query.captures[a]
                    if group == "module" then
                        local module_definition = ts_query.get_node_text(n, file_content)
                        unique_ids[i] = parse_definition(module_definition)
                    end
                end
            end
        else
            -- TODO notify user that the module is not known
            unique_ids[i] = nil
        end
    end
    -- rg -l -U --multiline-dotall -g '*.sv' -e "module\\s+clock_enable" .
end


function H:fill_portmaps()
    -- call every module:get_unfolded_instances
end

return H
