local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter.query

I = {}

function I:new(instance_tree, str_content, name)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               name = name,
               results = {},
               autoinstparam = false,
               autoinst = false,
               param_assignments = {},
               port_assignments = {},
               prams_all = {},
               vars_all = {}
              }
    setmetatable(d, self)
    self.__index = self
    -- d:get_parameters()
    -- d:get_macros()
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
    -- P(self.port_assignments)
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
    -- P(self.param_assignments)
end

function I:get_macros()
    local root = self.instance_tree:root()
    local param_query = vim.treesitter.parse_query("verilog",
    [[ ((comment) @macro (#match? @macro "/\\*\\u+\\*/")) ]])
    for _, n in param_query:iter_captures(root, self.str_content) do
        local txt = ts_query.get_node_text(n, self.str_content)
        if txt == "/*AUTOINST*/" then
            self.autoinst = true
        elseif txt == "/*AUTOINSTPARAM*/" then
            self.autoinstparam = true
        end
    end
end

function I:get_formated_variables()
end

-- rg -l -U --multiline-dotall -g "*.sv" -e "module\s+top" ./

-- needs to get the table of found definitions
--

function I:get_portmap_from_definition(def_path)
    if #def_path > 1 then
        print("functionality to pick inst definitions - not implemented yet")
    end
    local content = vim.fn.readfile(def_path[1])
    local file_content = vim.fn.join(content, "\n")
    local trees = LanguageTree.new(file_content, 'verilog', {})
    trees = trees:parse()
    if #trees <= 0 then
        return
    end

    local module_def_params = vim.treesitter.parse_query(
    "verilog", [[(named_port_connection  
                    (port_identifier) @id 
                    (expression) @value)@line
                ]])

    local module_def_ports = vim.treesitter.parse_query(
    "verilog", [[(named_port_connection  
                    (port_identifier) @id 
                    (expression) @value)@line
                ]])

    for i, n in module_def_params:iter_captures(trees:root(), file_content) do
        print(i, n)
    end
    for i, n in module_def_ports:iter_captures(trees:root(), file_content) do
        print(i, n)
    end
    -- find the module definition
    -- parse the portmap
    -- create table
end

function I:get_name()
    return self.name
end

-- TODO add settings file where you could specify paths to 
-- compilation and simulation libraries

-- TODO find all definitions for the module instances 
-- TODO find the remaining port names to be able to unfold them
-- TODO get the portmaps from each of the file (don't forget, that 
-- there could be more module definitions per file
-- TODO get the portmaps and if the user forgotten .* add it

function I:get_raw_instance()
    print(self.str_content)
end

return I
