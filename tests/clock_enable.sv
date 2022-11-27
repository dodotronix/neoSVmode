
// this is a top module
module clock_enable #(parameter RATIO=50)( 
    input logic rst,
    input logic clk,
    output logic o_en);

    logic [7:0] cnt;
    logic en; 

    always_ff @(posedge clk) begin
        if(rst) begin
            cnt <= '0;
        end else begin
            en <= '0;
            cnt <= cnt + 8'd1;
            if(cnt == RATIO) begin
                en <= 1'd1;
                cnt <= '0;
            end
        end
    end
    
    assign o_en = en;

endmodule
