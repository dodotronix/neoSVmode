local Instance = require("neoverilog.parser.instance")
local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

M = {}

function M:new(module_tree, str_content, line, indent)
    local d = {module_tree = module_tree,
               str_content = str_content,
               line = line,
               indent = indent,
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

function M.from_str_content(str_content, line, indent)
    local trees = LanguageTree.new(str_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
        return M:new(trees[1], str_content, line, indent)
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
        local i = Instance.from_str_content(node_text, range[1], range[2])
        if i ~= nil then
            local name = i:get_name()
            local position = i:get_lsp_position( self.line, self.indent )
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

    local name

    for i, n in macro_query:iter_captures(root, self.str_content) do
        local node_type = n:parent():type()
        if node_type == module_ts_type then
            local group = macro_query.captures[i]
            local range = { n:range() }
            if group == "macro" then
                local txt = ts_query.get_node_text(n, self.str_content)
                name = string.gsub(txt, "/%*(%u+)%*/", "%1")
                range[1] = range[1] + self.line
                range[3] = range[3] + self.line
                self.macros[name] = range
            else
                -- replace the end line number if the block
                -- of variables is closed with the "// end 
                -- of automatics" sentence
                self.macros[name][3] =  range[3] + self.line
                self.macros[name][4] =  range[4]
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
    local merged = {}
    local vars_merged= {}
    local vars_merged_new = {}

    for _, m in ipairs(self.instances) do
        local definitions, var_defs, a = m:get_macro_contents(list_of_definitions, self.line, self.indent)

        if (definitions ~= nil) then
            table.move(definitions, 1, #definitions, #merged + 1, merged)
        end
        if (var_defs ~= nil) then
            -- TODO create list of strings and save them to final table
            table.move(var_defs, 1, #var_defs, #vars_merged + 1, vars_merged)
        end

        -- merge the definitions of variables together
        if a ~= nil then
            for i in pairs(a) do
                if vars_merged_new[i] == nil then
                    vars_merged_new[i] = a[i]
                end
                for k, c in pairs(a[i]) do
                    -- TODO add get_instance_name to the instance class
                    vars_merged_new[i][k] = vars_merged_new[i][k] or c
                    if vars_merged_new[i][k].name == nil then
                        vars_merged_new[i][k].name = m:get_name()
                    else 
                        vars_merged_new[i][k].name = string.format("%s, %s",
                        vars_merged_new[i][k].name, m:get_name())
                    end
                end
            end
        end
    end

    -- create the var definitions
    for n, c in pairs(vars_merged_new) do
        local test_merged = { range={}, lines={} }
        if (self.macros[n] ~= nil) then
            table.insert(test_merged.lines, 1, "// Beginning of automatic reg inputs (for undeclared instantiated-module inputs)")
            table.insert(test_merged.lines, 1, string.format("/*%s*/", n))
            for k, l in pairs(c) do
                local var_stamp = string.format("%s %s; // From %s of %s",
                l.datatype, k, l.name, l.filename)
                table.insert(test_merged.lines, var_stamp)
            end
            table.insert(test_merged.lines, #test_merged.lines+1, "// End of automatics")
            test_merged.range = self.macros[n]
            table.insert(merged, #merged+1, test_merged)
        end
    end

    return merged
end

function M:get_raw_module()
    print(self.content_str)
    -- query.get_node_text(self.node, )
end

return M
