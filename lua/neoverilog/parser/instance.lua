local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

I = {}

function I:new(instance_tree, str_content, name, line, indent)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               indent = indent,
               line = line,
               align = -1,
               name = name,
               iname = "",
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
    d:parse_instance_name()
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
            self.align = range[2]
        elseif group == "asterisk" then
            self.asterisk = { n:range() }
            if self.align < 0 then
                self.align = self.asterisk[2]
            end
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

function I:get_unfolded_range(line)
    local root = self.instance_tree:root()
    local unfolded_query = vim.treesitter.query.parse("verilog",
    [[  ((named_port_connection) @asterisk (#eq? @asterisk "\.\*")) 
    (module_or_generate_item) @module ]])
    local range, group

    for i, n in unfolded_query:iter_captures(root, self.str_content) do
        group = unfolded_query.captures[i]
        local r  = { n:range() }
        -- TODO offset is not correctly added 
        if (group == "asterisk") then
            range[1] = r[1] + self.line + line - 1
            range[2] = r[2]
        else
            range = r
            range[3] = r[3] + self.line + line - 1
            range[4] = r[4]
        end
    end
    if group == "asterisk" then
        return { range=range, lines={".*);"} }
    end
    return nil
end

function I:get_name()
    return self.name
end

function I:get_instance_name()
    return self.iname
end

function I:parse_instance_name()
    local root = self.instance_tree:root()
    local inst_name_query = vim.treesitter.query.parse("verilog",
    [[ (name_of_instance) @iname ]])
    for _, n in inst_name_query:iter_captures(root, self.str_content) do
        self.iname = ts_query.get_node_text(n, self.str_content)
    end
end

function I:align_port_assignment(indent, id, ending)
    local indent = string.rep(" ", self.align)
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
            -- Ending should not be always used
            local def_stamp = self:align_port_assignment(indent, id, ",")
            local var_stamp = string.format("%s %s;", content.datatype, id)

            test[content.direction] = test[content.direction] or {}

            -- TODO add name of the file to the instance
            test[content.direction][id] = {datatype=content.datatype,
            filename=self.name}

            -- TODO check correct groupping of the variables AUTOWIRE  
            table.insert(ports.lines, def_stamp)
            table.insert(var_defs, var_stamp)
        end
    end

    -- add new line at the end of the portmap
    local bracket_indent = string.rep(" ", self.indent)
    table.insert(ports.lines, bracket_indent)

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
