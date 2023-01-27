--
-- instances = {
--      module_name : { 
--          id_name : value,
--          ports : { 
--              name : { 
--              width : value, 
--              type : value }, 
--              ...
--          }, 
--          parameters : { 
--              name : value,
--              param_value : value
--          },
--          asterisk_position : { row_start : value, 
--                                row_stop : value, 
--                                col_start : value, 
--                                col_stop : value 
--          },
--      },
--      ...
-- } 

local api = vim.api
local command = api.nvim_create_user_command

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

M = {}

command('NeoFold', M.fold, {})

return M
