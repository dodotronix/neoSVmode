
// this is a top module
module custom_sum #(parameter WIDTH=8)( 
    input logic rst,
    input logic clk,
    input logic [WIDTH-1:0] a,
    input logic [WDITH-1:0] b,
    output logic [WDITH:0] res);

    logic [7:0] r;

    always_ff @(posedge clk) begin
        if(rst) begin
            r <= '0;
        end else begin
            r <= a + b;
        end
    end

    assign res = r;

endmodule

