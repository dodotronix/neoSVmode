
// this is a top module
module module_nonansi_1 #(parameter int VARIABLE=50)(
    rst,
    clk,
    port_a,
    port_b);

    input logic rst;
    input logic clk;
    input logic [7:0] port_a;
    output logic port_b;

    // body of the nonansi module

endmodule

module module_nonansi_2 #(parameter int VARIABLE=10)(
    rst,
    clk,
    port_c,
    port_d);

    input rst;
    input clk;
    input [7:0] port_c;
    output port_d;

    // body of the nonansi module

endmodule


module module_ansi #(parameter int PARAM=21)(
    input logic clk,
    input logic rst,
    inout logic y,
    inout logic x,
    output logic z);

    // body of the module_nonansi

endmodule
