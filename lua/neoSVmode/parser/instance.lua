local LanguageTree = require('vim.treesitter.languagetree')
local ts_query = vim.treesitter

I = {}

function I:new(instance_tree, str_content, name, line, indent, extra_space)
    local d = {instance_tree = instance_tree,
               str_content = str_content,
               indent = indent,
               extra_space = extra_space,
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
    -- it to instances which don't have that and set the extra_space variable
    -- to 4, because we add 4 characters so we can subtract it from the ranges
    local ext_content, n = string.gsub(str_content, "([%w_]+)%s+([%w_]+.*)", "%1 #() %2")

    -- if the asterisk symbol is on the same line as the added #()
    -- we need to subtract extra sapaces from the ranges returned
    -- by the treesitter in later processing
    local first_line = string.match(str_content, "[^\n]+")
    local asterisk_symbol = string.match(first_line, "%.%*")

    local extra_space =  0
    if (n > 0) and (asterisk_symbol ~= nil ) then
        extra_space = 4
    end

    -- this is very important, if the parsed instance is placed inside a dummy 
    -- module, we can use the treesitter to parse the vars and identifiers 
    local w_content = string.format("module w;\n%s\nendmodule", ext_content)

    local trees = LanguageTree.new(w_content, 'verilog', {})
    trees = trees:parse()
    if #trees > 0 then
        return I:new(trees[1],  w_content, name, line, indent, extra_space)
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
            self.align = range[2] - self.extra_space
        elseif group == "asterisk" then
            self.asterisk = { n:range() }
            self.asterisk[2] = self.asterisk[2] - self.extra_space
            self.asterisk[4] = self.asterisk[4] - self.extra_space
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
        if (group == "asterisk") then
            range[1] = r[1] + self.line + line - 1
            range[2] = r[2] - self.extra_space
        else
            range = r
            -- There is one corner case when the
            -- closing bracket is at the same line
            -- as the asterisk.
            -- This can happen when the unfold
            -- method is called on the folded
            -- module or module with no ports.
            if range[1] == range[3] then
                range[4] = r[4] - self.extra_space
            end
            range[3] = r[3] + self.line + line - 1
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

function I:align_iface_assignment(id, modport)
    local indent = string.rep(" ", self.align)
    local port_def = string.format("%s.%s(%s.%s),", indent, id, id, modport) 
    -- TODO the indent is static for now, it's gonna be part of the setup
    return string.format("%-40s // *Implicit", port_def)
end

function I:align_port_assignment(id)
    local indent = string.rep(" ", self.align)
    local port_def = string.format("%s.%s(%s),", indent, id, id)
    -- TODO the indent is static for now, it's gonna be part of the setup
    return string.format("%-40s // *Implicit", port_def)
end

function I:get_macro_contents(list_of_definitions, line, indent)

    if(self.asterisk == nil) then
        return
    end

    local def_portmap = list_of_definitions[self.name]
    if(def_portmap == nil) then
        return
    end

    local ports = {range={}, lines={}}
    local definitions = {}
    local vardefs = {}
    local sorted = {}

    -- creating a portmap stamp
    -- TODO portassignment won't work if the def_portmap.port is empty
    for id, content in pairs(def_portmap.port) do
        if self.port_assignments[id] == nil then
            -- Ending should not be always used
            local def_stamp = self:align_port_assignment(id)

            vardefs[content.direction] = vardefs[content.direction] or {}

            -- TODO add name of the file to the instance
            vardefs[content.direction][id] = {datatype=content.datatype,
            filename=self.name}

            -- grouping the ports according to the direction
            if(sorted[content.direction] == nil) then
                sorted[content.direction] = {}
            end
            table.insert(sorted[content.direction], def_stamp)
        end
    end

    if def_portmap.iface ~= nil then
        for id, content in pairs(def_portmap.iface) do
            if self.port_assignments[id] == nil then
                local iface_stamp = self:align_iface_assignment(id, content.modport)
                if(sorted.interface == nil) then
                    sorted.interface = {}
                end
                table.insert(sorted.interface, iface_stamp)
            end
        end
    end

    -- merge all lists together and create names for the groups
    local merge_test = {","}
    for i, content in pairs(sorted) do
        local space = string.rep(" ", self.align)
        local delimiter = string.format("%s// %ss", space, i)
        table.insert(merge_test, #merge_test+1, delimiter)
        table.move(content, 1, #content, #merge_test + 1, merge_test)
    end
    -- remove the comma on the last line of port map
    merge_test[#merge_test] = string.gsub(merge_test[#merge_test], ",", " ")

    ports.lines = merge_test
    -- add new line at the end of the 
    -- portmap and align closing bracket
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

    return definitions, vardefs
end

-- TODO add settings file where you could specify paths to 
-- compilation and simulation libraries
-- TODO get the portmaps and if the user forgotten .* add it
-- rg -l -U --multiline-dotall -g "*.sv" -e "module\s+top" ./

function I:get_raw_instance()
    print(self.str_content)
end

return I
