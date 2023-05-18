local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

I = {}

function I:new(instance_tree, str_content, name, line, indent)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               indent = indent,
               line = line,
               align = 0,
               name = name,
               asterisk = {},
               autoinstparam = false,
               autoinst = false,
               param_assignments = {},
               port_assignments = {}
              }
    setmetatable(d, self)
    self.__index = self
    -- d:get_parameters()
    -- d:get_macros()
    d:get_ports()
    -- d:get_raw_instance()
    return d
end

function I.from_str_content(str_content, line, indent)

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
        return I:new(trees[1],  w_content, name, line, indent)
    end
    return nil
end

function I:get_ports()
    local root = self.instance_tree:root()
    local tmp = {}
    local ports_query = vim.treesitter.query.parse(
    "verilog", [[(named_port_connection  
                    (port_identifier) @id 
                    (expression) @value)@line
                    ((named_port_connection) @asterisk 
                    (#eq? @asterisk "\.\*"))
                ]])
    for i, n in ports_query:iter_captures(root, self.str_content) do
        local txt = ts_query.get_node_text(n, self.str_content)
        local group = ports_query.captures[i]
        if group == "line" then
            table.insert(tmp, 1, {})
            local range = {n:range()}
            self.align = range[1]
        elseif group == "asterisk" then
            self.asterisk = { n:range() }
        else
            tmp[1][group] = txt
        end

    end

    -- create dictionary for easier management
    for _, c in pairs(tmp) do
        local id = c.id
        local list = c
        list.id = nil -- remove name
        self.port_assignments[id] = list
    end
    -- P(self.port_assignments)
end

function I:get_parameters()
    local root = self.instance_tree:root()
    local param_query = vim.treesitter.query.parse("verilog",
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
    local param_query = vim.treesitter.query.parse("verilog",
    [[ ((comment) @macro (#match? @macro "/\\*\\u+\\*/")) ]])
    for _, n in param_query:iter_captures(root, self.str_content) do
        local txt = ts_query.get_node_text(n, self.str_content)
        if txt == "/*AUTOINST*/" then
            -- TODO save the position of the macro
            self.autoinst = true
        elseif txt == "/*AUTOINSTPARAM*/" then
            -- TODO save the position of the macro
            self.autoinstparam = true
        end
    end
end

function I:get_lsp_position(line, indent)
    return {character=self.indent + indent, line=self.line + line}
end

function I:get_name()
    return self.name
end

function I:align_port_assignment(indent, id, ending)
    local indent = string.rep(" ", indent+self.indent+self.align+1)
    return string.format("%s.%s(%s)%s // *Implicit", indent, id, id, ending)
end

function I:get_macro_contents(list_of_definitions, line, indent)

    if(self.asterisk == nil) then
        return
    end

    local def_portmap = list_of_definitions[self.name]
    if(def_portmap == nil) then
        return
    end

    local ports = {range={}, lines={","}}
    local var_defs = {}
    local definitions = {}
    local test = {}

    -- build stamp for the 
    for id, content in pairs(def_portmap.port) do
        if self.port_assignments[id] == nil then
            -- TODO sort the output according to the 
            -- add commentary to the signal
            local def_stamp = self:align_port_assignment(indent, id, ",")
            -- P(def_stamp)
            local var_stamp = string.format("%s %s;", content.datatype, id)
            local group
            if content.direction == "input" then
               group = "AUTOWIRE" 
            elseif content.direction == "output" then
               group = "AUTOREGINPUT" 
            elseif content.direction == "inout" then
               group = "AUTOINOUT" 
            end
            -- TODO create correct structure of the table
            -- TODO check correct groupping of the variables   
            table.insert(test[group], ) 
            table.insert(ports.lines, def_stamp)
            table.insert(var_defs, var_stamp)
        end
    end

    -- add new line at the end of the portmap
    table.insert(ports.lines, "")

    if next(self.asterisk) ~= nil then
        ports.range = {
            self.asterisk[1] + self.line + line - 1,
            self.asterisk[4],
            self.asterisk[3] + self.line + line - 1,
            self.asterisk[4]}
        definitions = {ports}
    end

    return definitions, var_defs, test
end

-- TODO add settings file where you could specify paths to 
-- compilation and simulation libraries
-- TODO get the portmaps and if the user forgotten .* add it
-- rg -l -U --multiline-dotall -g "*.sv" -e "module\s+top" ./

function I:get_raw_instance()
    print(self.str_content)
end

return I
