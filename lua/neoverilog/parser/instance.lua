local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter.query

I = {}

function I:new(instance_tree, str_content, name)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               name = name,
               autoparam = false,
               autoinst = false,
               param_assignments = {},
               port_assignments = {},
               prams_all = {},
               vars_all = {}
              }
    setmetatable(d, self)
    self.__index = self
    d:get_parameters()
    -- d:get_ports()
    -- d:get_raw_instance()
    return d
end

function I.from_str_content(str_content)

    local name = string.match(str_content, "[%w_]+")
    -- IMPORTANT there is an issue with treesitter that it doesn't recognize 
    -- module without the parameter brackets #(), therefore we have to inject
    -- it to instances which don't have that
    local ext_content = string.gsub(str_content, "([%w_]+)%s+([%w_]+.*)", "%1 #() %2")

    -- this is very important, if the parsed instance is placed inside a dummy 
    -- module, we can use the treesitter to parse the vars and identifiers 
    local w_content = string.format("module w;\n%s\nendmodule", ext_content)

    local trees = LanguageTree.new(w_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
            return I:new(trees[1],  w_content, name)
    end
    return nil
end

function I:get_ports()
    local root = self.instance_tree:root()
    local ports_query = vim.treesitter.parse_query(
    "verilog", [[(named_port_connection  
                    (port_identifier) @id 
                    (expression) @value)@line
                ]])
    for i, n in ports_query:iter_captures(root, self.str_content) do
        local txt = ts_query.get_node_text(n, self.str_content)
        local group = ports_query.captures[i]
        if group == "line" then
            table.insert(self.port_assignments, 1, {})
        else
            self.port_assignments[1][group] = txt
        end
    end
    P(self.port_assignments)
end

function I:get_parameters()
    local root = self.instance_tree:root()
    local param_query = vim.treesitter.parse_query("verilog",
    [[ (named_parameter_assignment  
        (parameter_identifier) @id 
        (param_expression) @value)@line  
    ]])
    for i, n in param_query:iter_captures(root, self.str_content) do
        local txt = ts_query.get_node_text(n, self.str_content)
        local group = param_query.captures[i]
        if group == "line" then
            table.insert(self.param_assignments, 1, {})
        else
            self.param_assignments[1][group] = txt
        end
    end
    P(self.param_assignments)
end

function I:get_macros()

end

function I:get_formated_variables()

end

function I:get_portmap_from_definition()
    -- find the module definition
    -- parse the portmap
    -- create table
end

-- TODO find all definitions for the module instances 
-- TODO find the remaining port names to be able to unfold them
-- TODO get the portmaps from each of the file (dont forget, that 
-- there could be more module definitions per file
-- TODO get the portmaps and if the user forgotten .* add it

function I:get_raw_instance()
    print(self.str_content)
end

return I
