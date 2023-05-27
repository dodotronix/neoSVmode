
module UnfoldTest #()
(input logic haha);

/*AUTOWIRE*/
// Beginning of automatic wires outputs (for undeclared instantiated-module outputs)
logic res2;                              // From i_simple_module_ansi of io_simple_module_ansi.sv
logic fdbk;                              // From i_simple_module_ansi of io_simple_module_ansi.sv
logic res1;                              // From i_simple_module_ansi of io_simple_module_ansi.sv
// End of automatics

/*AUTOREGINPUT*/
// Beginning of automatic regs inputs (for undeclared instantiated-module inputs)
logic clk;                               // To i_simple_module_ansi of io_simple_module_ansi.sv
logic en;                                // To i_simple_module_ansi of io_simple_module_ansi.sv
logic [7:0] data;                        // To i_simple_module_ansi of io_simple_module_ansi.sv
logic rst;                               // To i_simple_module_ansi of io_simple_module_ansi.sv
// End of automatics


// interface_module_ansi i_iface_module(.*);

io_simple_module_ansi i_simple_module_ansi(.*);

// module_nonansi i_nonansi_m (.*);

// module_ansi i_nonansi_m (.*);

endmodule
