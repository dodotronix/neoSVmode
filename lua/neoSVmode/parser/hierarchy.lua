local api = vim.api
local ts_query = vim.treesitter
local Module = require("neoSVmode.parser.module")
local util = require('vim.lsp.util')
local LanguageTree = require('vim.treesitter.languagetree')

-- TODO maybe add a memoization module to store all the found paths 
-- and store the values in /tmp/ under unique number for a certain branch

local H = {}

function H:new(tree, content, str_content)
    local d = {tree = tree,
               content = content,
               unique_ids = {},
               module_file_names = {},
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
        local m = Module.from_str_content(node_text, range[1], range[2])
        table.insert(self.modules, m)
    end
end

function H:get_unique_names()
    for _, m in ipairs(self.modules) do
        self.unique_ids = m:get_unique_names(self.unique_ids)
    end
    return self.unique_ids
end

function H:find_definitions()

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

            -- TODO parsers
            local param_check_type_query = [[ 
            (module_nonansi_header)@nonansi
            (module_ansi_header) @ansi ]]

            local port_nonansi_query = [[
            (input_declaration) @port_nonansi 
            (output_declaration) @port_nonansi
            (inout_declaration) @port_nonansi
            ]]

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

            -- decide what is the module definition standard
            local parsers = {}
            local check_type_parser = vim.treesitter.query.parse("verilog", param_check_type_query)
            for i, _ in check_type_parser:iter_captures(trees[1]:root(), content) do
                local group = check_type_parser.captures[i]
                if group == "nonansi" then
                    -- NOTE parsing of the interfaces is not implemented
                    parsers.param = vim.treesitter.query.parse("verilog", param_query)
                    parsers.port = vim.treesitter.query.parse("verilog", port_nonansi_query)
                elseif group == "ansi" then
                    parsers.param = vim.treesitter.query.parse("verilog", param_query)
                    parsers.port = vim.treesitter.query.parse("verilog", port_query)
                    parsers.iface = vim.treesitter.query.parse("verilog", interface_query)
                else
                    return
                end
            end

            for name, p in pairs(parsers) do
                local tmp = {}
                for a, n in p:iter_captures(trees[1]:root(), content) do
                    local group = p.captures[a]
                    -- next param, port, iface definition
                    -- create new empty list to store the
                    -- parsed values from the TS query
                    if parsers[group] ~= nil then
                        table.insert(tmp, 1, {})
                    elseif group == "port_nonansi" then
                        local t = {}
                        local txt = ts_query.get_node_text(n, content)
                        for k in string.gmatch(txt, "([%w_:%[%]%d]+)") do
                            table.insert(t, #t+1, k)
                        end
                        local datatype = "logic"
                        local id = t[2]
                        if t[4] ~= nil then
                            id = t[4]
                            datatype = t[2] .. " " .. t[3]
                        elseif t[3] ~= nil then
                            id = t[3]
                            if t[2] ~= datatype then
                                datatype = datatype .. " " .. t[2]
                            end
                        end

                        table.insert(tmp, 1, {})
                        tmp[1].direction = t[1]
                        tmp[1].datatype = datatype
                        tmp[1].name = id
                    else
                        tmp[1][group] = ts_query.get_node_text(n, content)
                    end
                end

                -- create dictionary for easier management
                local parsed = {}
                for _, c in pairs(tmp) do
                    local id = c.name
                    local list = c
                    list.name = nil -- remove name
                    parsed[id] = list
                end
                res[name] = parsed
            end
        end
        return res
    end

    self:get_unique_names()
    for i, p in pairs(self.unique_ids) do
        local res, err = vim.lsp.buf_request_sync(
        0, "textDocument/definition", make_position_param(p))
        local result = res[1].result[1]

        if result ~= nil then
            local path = vim.uri_to_fname(result.uri)
            local fname = string.gsub(path, ".*%/([%w_]+)", "%1")
            self.module_file_names[i] = fname
            local content = vim.fn.readfile(path)
            local file_content = vim.fn.join(content, "\n")
            -- self.unique_ids[i] = path

            local trees = LanguageTree.new(file_content, 'verilog', {})
            trees = trees:parse()
            if #trees > 0 then
                -- NOTE be careful the the module pattern has to be enclosed
                -- in the brackets
                local mmatch = string.format("%q", "module " .. i)
                local pattern = string.format("(module_declaration (module_header) @m (#match? @m %s)) @module", mmatch)

                local def_query = vim.treesitter.query.parse("verilog", pattern)

                for a, n in def_query:iter_captures(trees[1]:root(), file_content) do
                    local group = def_query.captures[a]
                    if group == "module" then
                        local module_definition = ts_query.get_node_text(n, file_content)
                        self.unique_ids[i] = parse_definition(module_definition)
                        -- P(self.unique_ids[i])
                    end
                end
            end
        else
            -- TODO notify user that the module is not known
            self.unique_ids[i] = nil
        end
    end
end

function H:unfold_macros(bufnr)
    -- TQDQ place in utils.lua
    local merged = {}
    self:find_definitions()
    for _, m in ipairs(self.modules) do
        local definitions = m:get_macro_contents(self.unique_ids, self.module_file_names)
        table.move(definitions, 1, #definitions, #merged + 1, merged)
        -- break -- just for testing
    end

    -- sort the maps according to the line  
    -- from the highest line number to the lowest
    table.sort(merged, function (a, b)
        if(a.range[1] > b.range[1]) then
            return true
        else
            return false
        end
    end)

    for _, n in pairs(merged) do
        api.nvim_buf_set_text(bufnr, n.range[1], n.range[2],
        n.range[3], n.range[4], n.lines)
    end
end

function H:fold_macros(bufnr)
    local merged = {}
    for _, m in ipairs(self.modules) do
        local definitions = m:get_unfolded_range()
        table.move(definitions, 1, #definitions, #merged + 1, merged)
    end

    table.sort(merged, function (a, b)
        if(a.range[1] > b.range[1]) then
            return true
        else
            return false
        end
    end)

    for _, n in pairs(merged) do
        api.nvim_buf_set_text(bufnr, n.range[1], n.range[2],
        n.range[3], n.range[4], n.lines)
    end
end

return H
