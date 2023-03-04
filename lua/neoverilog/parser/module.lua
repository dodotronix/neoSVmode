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

function M:get_raw_module()
    print(self.content_str)
    -- query.get_node_text(self.node, )
end

return M
