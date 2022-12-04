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
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic [7:0] cnt;
   // End of automatics
   
    /*AUTOOUTPUT*/
    // logic

    clock_enable #(.RATIO(10)) u_clken (
        .o_en(o_en),
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
