
module UnfoldTest (input logic ctrl,
                   output logic [31:0] res,
                   input logic manual_rst);

/*AUTOWIRE*/

/*AUTOREGINOUT*/

/*AUTOREGINPUT*/

interface_module_ansi i_iface_module(.*);

io_simple_module_ansi i_simple_module_ansi(
    .res2(ahoj),
    .*);

module_nonansi_2 i_nonansi_2_m (.*);

module_nonansi_1 i_nonansi_1_m (.*);

module_ansi i_ansi_m (.*);

endmodule
