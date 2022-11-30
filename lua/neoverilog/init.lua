--
-- TODO remove non-existing ports in the portmaps above the .*
-- TODO remove all lines behind the .* until );
-- TODO align placed portmaps refering to the verilog alignment rules
-- TODO detect all places with /*AUTOWIRE*/, /*AUTOAREGINPUT*/ 
-- TODO create signals declarations 
-- TODO place the signal declarations within the 
-- {// Beginning of automatic wires (for undeclared instantiated-module outputs)}
-- {// End of automatics}

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


local get_root = function (bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "verilog", {})
    local tree = parser:parse()[1]
    return tree:root()
end

local align = function ()
    print("alignment")
end

local find_modules = function()
    local hdl_paths = {}
    local found_defintions = {}
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

local create_port_map = function (pre, port_table, post)
    local result = {pre}
    for i, tab in pairs(port_table) do
        local separator = ","
        if(i == #port_table) then
            separator = ""
        end
        table.insert(result,
        string.format(".%s(%s)%s", tab.name, tab.name, separator))
    end

    result[#result+1] = post
    return result
end

local M = {}

M.unfold = function ()
    local name
    local bufnr = api.nvim_get_current_buf()
    local root = get_root(bufnr)
    local modules = get_module_table()
    local found_instances = {}

    for id, node in asterisk_instances:iter_captures(root, bufnr, 0, -1) do
        local group = asterisk_instances.captures[id]
        if(group == "inst_name") then
            name = vim.treesitter.get_node_text(node, bufnr, {})
        elseif(group == "asterisk" ) then
            local range = { node:range() }
            table.insert(found_instances, 1, {
                name = name,
                start = range[1],
                stop = range[3]+1})
            end
        end

    for i, tab in pairs(found_instances) do
        local asterisk_line = api.nvim_buf_get_lines(bufnr, tab.start, tab.start+1, false)[1]
        local line_ending = vim.fn.substitute(asterisk_line, '.*\\.\\*\\(.*\\)', '\\1', '')
        local unfolded = create_port_map(".*,", modules[tab.name], line_ending)
        found_instances[i].port = unfolded
    end

    for _, f in ipairs(found_instances) do
        api.nvim_buf_set_lines(bufnr, f.start, f.stop, false, f.port)
    end
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
            local connections = get_folded_portmap(node, bufnr)
            local module_def = modules[name]
            -- check if the ports from current buffer corespond 
            -- to the found ports in the module definitions
            -- TODO check for duplicates
            for i, c in pairs(connections) do
                print(c.port_name)
                for _, d in pairs(module_def) do
                    if(d.name == c.port_name) then
                        table.insert(new_portmap, 1, c)
                        break
                    end
                end
            end
            P(new_portmap)
        end
    end
end

command('NeoUnfold', M.unfold, {})
command('NeoFold', M.fold, {})

return M
