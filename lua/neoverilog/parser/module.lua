local Instance = require("neoverilog.parser.instance")
local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

M = {}

function M:new(module_tree, str_content, start_offset, end_offset)
    local d = {module_tree = module_tree,
               str_content = str_content,
               start_offset = start_offset,
               end_offset = end_offset,
               unique_names = {},
               instances = {},
               macros = {}
              }
    setmetatable(d, self)
    self.__index = self
    d:get_instantiations()
    d:get_macros()
    -- d:get_raw_module()
    return d
end

function M.from_str_content(str_content, start_offset, end_offset)
    local trees = LanguageTree.new(str_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
        return M:new(trees[1], str_content, start_offset, end_offset)
    end
    return nil
end

function M:get_instantiations()
    local  instance_query = vim.treesitter.query.parse(
    "verilog", [[((module_or_generate_item) @t 
    (#match? @t "\\w+\\s*\\w+\\s*\\((\\.\\([\\w_]*\\))|(\\s*(\\.\\*\\s*),?)*\\);"))]])
    for _, n in instance_query:iter_captures(self.module_tree:root(), self.str_content) do
        local node_text = ts_query.get_node_text(n, self.str_content, false)
        local range = { n:range() }
        local start_offset = {range[1], range[2]}
        local end_offset = {range[3], range[4]}
        local i = Instance.from_str_content(node_text, start_offset, end_offset)
        if i ~= nil then
            local name = i:get_name()
            local position = i:get_lsp_position( self.start_offset[1], self.start_offset[2])
            self.unique_names[name] = position
        end
        table.insert(self.instances, i)
    end
end

function M:get_macros()
    local root = self.module_tree:root()
    local module_ts_type = root:child():type()
    local  macro_query = vim.treesitter.query.parse(
    "verilog", [[
    ((comment) @macro (#match? @macro "\\/\\*[A-Z]+\\*\\/"))
    ((comment) @end (#match? @end "// End of automatics"))]])
    for i, n in macro_query:iter_captures(root, self.str_content) do
        local node_type = n:parent():type()
        if node_type == module_ts_type then
            local group = macro_query.captures[i]
            local range = { n:range() }
            if group == "macro" then
                local txt = ts_query.get_node_text(n, self.str_content)
                local name = string.gsub(txt, "/%*(%u+)%*/", "%1")
                table.insert(self.macros, 1, {})
                self.macros[1] = {name = name,
                start_line = range[1],
                stop_line = range[3]}
            else
                -- replace the end line number if the block
                -- of variables is closed with the "// end 
                -- of automatics" sentence
                self.macros[1].stop_line = range[3]
            end
        end
    end
end

function M:get_unique_names(unique_names_buffer)
    local tmp = unique_names_buffer
    for name, pos in pairs(self.unique_names) do
        tmp[name] = pos
    end
    return tmp
end

function M:get_macro_contents(list_of_definitions)
    -- dummy function portmap

    local merged = {}
    local vars_merged= {}

    for _, m in ipairs(self.instances) do
        local definitions, var_defs = m:get_macro_contents(list_of_definitions)
        table.move(definitions, 1, #definitions, #merged + 1, merged)
        table.move(var_defs, 1, #var_defs, #vars_merged + 1, vars_merged)
    end

    local vers_defs_packed = { range={}, lines={} }
    vers_defs_packed.lines = vars_merged

    -- TODO fill the range based on the macro position
    vers_defs_packed.range = { 14, 0, 21, 24 }

    -- add the vars to the merged table
    table.insert(merged, #merged+1, vers_defs_packed)

    return merged

    --[[ return {
        {
            range={ 14, 0, 21, 24 },
            lines={
                "// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)",
                "logic [31:0] signal1; // To instance_name of module_name.sv",
                "logic [31:0] signal2; // To instance_name of module_name.sv",
                "logic signal3; // To instance_name1 of module_name1.sv",
                "// End of automatics"
            }
        },
        {
            range={ 41, 10, 41, 10 },
            lines={
                ",",
                "// Inputs",
                ".signal1(signal1[31:0]), // *Implicit",
                "// Output",
                ".signal2(signal2[31:0]), // *Implicit",
                ""
            }
        },
        {
            range={ 36, 31, 36, 31 },
            lines={
                "",
                ".TEST1(TEST1),",
                ".TEST2(TEST2)"
            }
        }
    } ]]
end

function M:get_raw_module()
    print(self.content_str)
    -- query.get_node_text(self.node, )
end

return M
