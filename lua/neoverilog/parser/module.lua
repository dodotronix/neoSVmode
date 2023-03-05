local Instance = require("neoverilog.parser.instance")
local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter.query

M = {}

function M:new(module_tree, str_content)
    local d = {module_tree = module_tree,
               str_content = str_content,
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

function M.from_str_content(str_content)
    local trees = LanguageTree.new(str_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
        return M:new(trees[1], str_content)
    end
    return nil
end

function M:get_instantiations()
    local  instance_query = vim.treesitter.parse_query(
    "verilog", [[((module_or_generate_item) @t 
    (#match? @t "\\w+\\s*\\w+\\s*\\((\\.\\([\\w_]*\\))|(\\s*(\\.\\*\\s*),?)*\\);"))]])
    for _, n in instance_query:iter_captures(self.module_tree:root(), self.str_content) do
        local node_text = ts_query.get_node_text(n, self.str_content, false)
        local i = Instance.from_str_content(node_text)
        table.insert(self.instances, i)
    end
end

function M:get_macros()
    local root = self.module_tree:root()
    local module_ts_type = root:child():type()
    local  macro_query = vim.treesitter.parse_query(
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

function M:get_raw_module()
    print(self.content_str)
    -- query.get_node_text(self.node, )
end

return M
