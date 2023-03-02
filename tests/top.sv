// this is a top module

module top #(parameter int TEST=32, 
    parameter int TEST2=32) (
    input logic rst,
    input logic clk,
    input logic sw,
    t_test.consumer new_iface,
    output logic [7:0] data);

    localparam test = 10;
    logic sw_toggle;

    /*AUTOWIRE*/
    // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
    logic [31:0]         InRawMem_data_i;        // To i_bsra_core_wb of bsra_core_wb.v
    logic [31:0]         Token_i;                // To i_bsra_core_wb of bsra_core_wb.v
    logic                new_filtered_data;      // To i_bsra_core_wb of bsra_core_wb.v
    logic                new_inraw_data;         // To i_bsra_core_wb of bsra_core_wb.v
    logic                new_raw_data;           // To i_bsra_core_wb of bsra_core_wb.v
    logic                sum_cycle_error;        // To i_bsra_core_wb of bsra_core_wb.v
    // End of automatics
    /*AUTOOUTPUT*/
    logic                sum_cycle_error;
    // End of automatics
    /*AUTOREGINPUT*/

    clock_enable u_clken (
        .o_en(something),
        .*);

    clock_enable #(.RATIO(10)) u_clken1 (
        .*);

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt <= '0;
        end else begin
            if(sw) sw_toggle <= sw_toggle ^ '1;
            if(o_en) cnt <= (sw_toggle) ? cnt + 1 : cnt;
        end
    end

    /* always_comb begin
        a = 1'b1;
        f = {{4{1'b1}}, 2'b1};
        b = 1'b0;
    end

    assign c = 1'b0;
    assign d = 1'b0;
    assign e = 1'b0; */

endmodule

module haha ( input logic rst,
    input logic clk,
    input logic sw,
    t_test.consumer new_iface,
    output logic [7:0] data);

endmodule
