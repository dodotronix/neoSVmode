local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

I = {}

function I:new(instance_tree, str_content, name, start_offset, end_offset)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               start_offset = start_offset,
               end_offset = end_offset,
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

function I.from_str_content(str_content, start_offset, end_offset)

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
            return I:new(trees[1],  w_content, name, start_offset, end_offset)
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

function I:get_lsp_position(line_offset, char_offset)
    return {character=self.start_offset[2] + char_offset,
            line=self.start_offset[1] + line_offset}
end

function I:get_name()
    return self.name
end

function I:get_macro_contents(list_of_definitions, offset)

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

    -- build stamp for the 
    for id, content in pairs(def_portmap.port) do
        if self.port_assignments[id] == nil then
            -- TODO sort the output according to the 
            -- add commentary to the signal
            local def_stamp = string.format(".%s(%s), // *Implicit", id, id)
            local var_stamp = string.format("%s %s;", content.datatype, id)
            table.insert(ports.lines, def_stamp)
            table.insert(var_defs, var_stamp)
        end
    end

    -- add new line at the end of the portmap
    table.insert(ports.lines, "")

    if next(self.asterisk) ~= nil then
        ports.range = {
            self.asterisk[1]+self.start_offset[1] + offset[1] - 1,
            self.asterisk[4],
            self.asterisk[3]+self.start_offset[1] + offset[1] - 1,
            self.asterisk[4]}
        definitions = {ports}
    end

    return definitions, var_defs
end

-- TODO add settings file where you could specify paths to 
-- compilation and simulation libraries

-- TODO find all definitions for the module instances 
-- TODO find the remaining port names to be able to unfold them
-- TODO get the portmaps from each of the file (don't forget, that 
-- there could be more module definitions per file
-- TODO get the portmaps and if the user forgotten .* add it
-- rg -l -U --multiline-dotall -g "*.sv" -e "module\s+top" ./

function I:get_raw_instance()
    print(self.str_content)
end

return I
