--
-- TODO load it as git package to nvim
-- TODO rewrite the code to be better organized

local api = vim.api
local command = api.nvim_create_user_command
local augroup = api.nvim_create_augroup

local module_name = vim.treesitter.parse_query(
"verilog",
[[
((module_header 
   (simple_identifier) @module_name))
]])

local module_ports = vim.treesitter.parse_query(
"verilog",
[[
(ansi_port_declaration 
    (_ (port_direction) @dir
       (data_type) @datatype)
    (port_identifier) @name
) @port
]])

local module_interfaces = vim.treesitter.parse_query(
"verilog",
[[
(ansi_port_declaration 
  (_ (interface_identifier) @iface
     (modport_identifier) @modport)
  (port_identifier) @name
) @port
]])

local module_generics = vim.treesitter.parse_query(
"verilog",
[[
(parameter_port_list 
  (parameter_port_declaration 
    (parameter_declaration 
      (list_of_param_assignments 
        (param_assignment 
          (parameter_identifier) @module_param_name)))))
]])


local asterisk_instances = vim.treesitter.parse_query(
"verilog",
[[
(module_instantiation
  (simple_identifier) @inst_name
  (hierarchical_instance 
    (list_of_port_connections 
      (named_port_connection) @asterisk 
      (#eq? @asterisk ".*"))@port_map
))
]])

local portmap_check = vim.treesitter.parse_query(
"verilog",
[[
(named_port_connection 
  (port_identifier 
    (simple_identifier) @port_name)*
  (expression 
    (_ (simple_identifier) @connector))*

)@port_complete 
(comment) @comment
]])


-- NOTE This is intended to be compatible with emacs verilog-mode
-- not all the macros are supported yet and some off them are not
-- priority so they have not been included yet
local neoverilog_macros = vim.treesitter.parse_query(
"verilog",
[[
((comment) @autowire 
 (#match? @autowire "\\/\\*AUTOWIRE\\*\\/")) 
((comment) @autooutput 
 (#match? @autooutput "\\/\\*AUTOOUTPUT\\*\\/")) 
((comment) @autoinput 
 (#match? @autoinput "\\/\\*AUTOINPUT\\*\\/")) 
((comment) @autoinst 
 (#match? @autoinst "\\/\\*AUTOINST\\*\\/")) 
((comment) @autoinstparam 
 (#match? @autoinstparam "\\/\\*AUTOPARAM\\*\\/")) 
((comment) @autoinputreg 
 (#match? @autoinputreg "\\/\\*AUTOINPUTREG\\*\\/")) 
((comment) @autounused
 (#match? @autounused "\\/\\*AUTOUNUSED\\*\\/")) 
(((comment) @pre_comment
(#eq? @pre_comment "// Beginning of automatic wires (for undeclared instantiated-module outputs)"))
(_) 
((comment) @post_comment 
(#eq? @post_comment "// End of automatics")))
]])

local INDENT_PATTERN = '^%s+'

local function get_indents(lines)
  local indents = vim.tbl_map(function(line)
    local indent = line:match(INDENT_PATTERN)
    return indent and #indent or 0
  end, lines)
  -- Dont skip first line indentation
  indents[1] = 0
  return indents
end

local get_root = function (bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "verilog", {})
    local tree = parser:parse()[1]
    return tree:root()
end

local get_indent = function(indent)
    local spaces = ''
    for i = 0, indent do
       spaces = string.format('%s%s', spaces, ' ')
    end
    return spaces
end

local find_modules = function()
    local hdl_paths = {}
    local test = require'plenary.scandir'
    local filetype = require'plenary.filetype'
    local dirs = test.scan_dir(".", {hidden = false, depth = nil})
    for _, d in pairs(dirs) do
        local f = filetype.detect_from_extension(d)
        if(f == "systemverilog" or f == "verilog") then
            table.insert(hdl_paths, d)
        end
    end
    return hdl_paths
end

local get_port_table = function (module_parser, module_content)
    local port_map_table = {}
    for id, node in module_ports:iter_captures(module_parser, module_content,
        module_parser:start(), module_parser:end_()) do
        local group = module_ports.captures[id]
        local group_content = vim.treesitter.get_node_text(node, module_content, {})
        if(group == "port") then
            table.insert(port_map_table, 1, { })
        else
            port_map_table[1][group] = group_content
        end
    end
    for id, node in module_interfaces:iter_captures(module_parser, module_content,
        module_parser:start(), module_parser:end_()) do
        local group = module_interfaces.captures[id]
        local group_content = vim.treesitter.get_node_text(node, module_content, {})
        if(group == "port") then
            table.insert(port_map_table, 1, { })
        else
            port_map_table[1][group] = group_content
        end
    end

    return port_map_table
end

local copy_port_table = function (module_table, name)
    local copy = {}
    local module_portmap = module_table[name]

    for _, port in ipairs(module_portmap) do
        local port_table = {}
        for k, v in pairs(port) do
            port_table[k] = v
        end
        table.insert(copy, port_table)
    end

    return copy
end

-- TODO create list of variable definitions 
-- and put the in the test file
local get_macro_locations = function ()
    local bufnr = api.nvim_get_current_buf()
    local root = get_root(bufnr)
    local macro_positions = {}
    local macro_name

    for id, node in neoverilog_macros:iter_captures(root, bufnr, 0, -1) do
        local group = neoverilog_macros.captures[id]
        local range = { node:range() }
        if (group == "post_comment") then
            macro_positions[macro_name].stop_row = range[3] + 1
        elseif (group == "pre_comment") then
            macro_positions[macro_name].start_row = range[1]
        else
            macro_name = group
            macro_positions[macro_name] = {}
            macro_positions[macro_name].start_row = range[1] + 1
            macro_positions[macro_name].start_col = range[2]
            macro_positions[macro_name].stop_row = range[1] + 1
            macro_positions[macro_name].stop_col = 0
        end
    end

    -- this is just a TEST
    -- try to remove the variable definitions based on the
    --[[ for _, f in pairs(macro_positions) do
        api.nvim_buf_set_text(bufnr, f.start_row, f.start_col,
        f.stop_row, f.stop_col, {})
    end ]]

    return macro_positions
end

local get_module_table = function ()

    local hdl_paths = find_modules()
    local portmaps = {}

    for _, i in pairs(hdl_paths) do
        -- get string
        local content = vim.fn.readfile(i)
        local str_content = vim.fn.join(content, "\n")

        local file_parser = vim.treesitter.get_string_parser(str_content, "verilog", {})
        local tree = file_parser:parse()[1]
        local root = tree:root()

        for _, node in module_name:iter_captures(root, str_content, root:start(), root:end_()) do
            local name = vim.treesitter.get_node_text(node, str_content, {})
            portmaps[name] = get_port_table(root, str_content)
        end
    end
    return portmaps
end

local get_folded_portmap = function (root, bufnr)

    local portmap = {}

    for id, node in portmap_check:iter_captures(root, bufnr, 0, -1) do
        local group = portmap_check.captures[id]
        local txt = vim.treesitter.get_node_text(node, bufnr, {})
        if(txt == ".*") then
            break
        else
            if (group == "port_complete") then
                table.insert(portmap, 1, {
                    definition = txt,
                    port_name = "",
                    line_number = node:range(),
                    connector = "",
                    comment = ""})
            else
                portmap[1][group] = txt
            end
        end
    end
    return portmap
end

local create_port_map = function (pre, port_table, result, indent)
    result[#result+1] = string.format("%s%s", indent, pre)
    for i, tab in pairs(port_table) do
        local separator = ","
        if(i == #port_table) then
            separator = ""
        end
        table.insert(result,
        string.format("%s.%s(%s)%s", indent, tab.name, tab.name, separator))
    end
end

local create_var_defs = function (result, port_table, indent, existing)
    local var_exists = function (list, var)
        for i = 1, #list do
            if(list[i] == var) then
                return true
            end
        end
        table.insert(existing, var)
        return false
    end
    for _, tab in pairs(port_table) do
        if(not var_exists(existing, tab.name)) then
            print(tab.name)
            table.insert(result,
            string.format("%s%s %s;", indent, tab.datatype, tab.name))
        end
    end
end

local M = {}

M.unfold = function ()
    local name, offset, port_indent
    local bufnr = api.nvim_get_current_buf()
    local root = get_root(bufnr)
    local modules = get_module_table()
    local new_portmap = {}
    local locations = get_macro_locations()
    local var_indent = get_indent(locations["autowire"].start_col)
    local vardefs = {string.format("%s// Beginning of automatic wires (for undeclared instantiated-module outputs)", var_indent)}
    local existing_vars = {}

    for id, node in asterisk_instances:iter_captures(root, bufnr, 0, -1) do
        local range = { node:range() }
        local group = asterisk_instances.captures[id]
        if(group == "inst_name") then
            name = vim.treesitter.get_node_text(node, bufnr, {})
            offset = range[2]
            port_indent = get_indent(offset)
        elseif(group == "port_map" ) then
            local connections = get_folded_portmap(node, bufnr)
            local module_def = copy_port_table(modules, name)

            table.insert(new_portmap, 1, {
                start_row = range[1],
                stop_row = range[3],
                start_col = range[2],
                stop_col = range[4]
            })
            -- check if the ports from current buffer corespond 
            -- to the found ports in the module definitions
            local ports = {}
            for _, c in pairs(connections) do
                for i, d in pairs(module_def) do
                    if(d.name == c.port_name) then
                        -- TODO check for duplicates (maybe in the future)
                        -- TODO maybe check if the connection exists (optional) 
                        -- need to add comma at the end of port
                        table.insert(ports, string.format("%s%s,", port_indent, c.definition))
                        table.remove(module_def, i)
                        break
                    end
                end
            end
            -- add .* at the end of the portmap
            -- merge unfolded portmap part with manualy assigned ports
            create_port_map(".*,", module_def, ports, port_indent)
            create_var_defs(vardefs, module_def, var_indent, existing_vars)

            new_portmap[1].txt = ports
        end
    end
    -- add definitions of variables at the last place in table
    -- TODO needs to be changed in the future - the place in
    -- the final table has to be adjusted according to the
    -- places of macros in the file
    vardefs[#vardefs+1] = string.format("%s// End of automatics", var_indent)
    vardefs[#vardefs+1] = "" -- place empty line
    table.insert(new_portmap, {
        start_row = locations["autowire"].start_row,
        stop_row = locations["autowire"].stop_row,
        start_col = locations["autowire"].start_col,
        stop_col = locations["autowire"].stop_col,
        txt = vardefs
    })
    -- TODO we have to create array with all the ports an ddefinitions to be
    -- undfolded, and sort it refering to their line number
    for _, f in ipairs(new_portmap) do
        api.nvim_buf_set_text(bufnr, f.start_row, 0,
                              f.stop_row, f.stop_col, f.txt)
    end
end

M.fold = function ()
    local name
    local bufnr = api.nvim_get_current_buf()
    local root = get_root(bufnr)
    local modules = get_module_table()
    local new_portmap = {}

    for id, node in asterisk_instances:iter_captures(root, bufnr, 0, -1) do
        local group = asterisk_instances.captures[id]
        if(group == "inst_name") then
            name = vim.treesitter.get_node_text(node, bufnr, {})
        elseif(group == "port_map" ) then
            --[[ local test = vim.treesitter.get_node_text(node, bufnr, {})
            print(test) ]]
            local connections = get_folded_portmap(node, bufnr)
            local module_def = modules[name]

            local range = { node:range() }
            table.insert(new_portmap, 1, {
                txt = {},
                start_row = range[1],
                stop_row = range[3],
                start_col = range[2],
                stop_col = range[4]
            })

            -- check if the ports from current buffer corespond 
            -- to the found ports in the module definitions
            for i, c in pairs(connections) do
                for _, d in pairs(module_def) do
                    if(d.name == c.port_name) then
                        -- need to add comma at the end of port
                        table.insert(new_portmap[1].txt,
                        string.format("%s,", c.definition))
                        -- TODO check for duplicates (maybe in the future)
                        break
                    end
                end
            end
            -- add .* at the end new_portmapof the portmap
            table.insert(new_portmap[1].txt, ".*")
        end
    end

-- TODO place the signal declarations within the 
    for _, f in ipairs(new_portmap) do
        api.nvim_buf_set_text(bufnr, f.start_row, f.start_col,
                              f.stop_row, f.stop_col, f.txt)
    end
end

command('NeoUnfold', M.unfold, {})
command('NeoFold', M.fold, {})

return M
