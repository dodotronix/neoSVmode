
module vunit_tb;

// interfaces
t_clock Clk_x();
t_control ctrl_x();
t_bus bus_x();
iface general_x();

default clocking cb @(posedge Clk_x.Defalut100Mhz.clk);
   endclocking

logic [31:0] dynamic_data;

`TEST_SUITE begin
    `TEST_SUITE_SETUP begin
        Clk_x.reset = 1'b1;
        dynamic_data = '0;
    end

    `TEST_CASE("link_verification") begin
        #5us;
        Clk_x.reset = 1'b0;
        dynamic_data = 1'b1;
        #10us;
        `CHECK_EQUAL (1,1);
    end
end;

interface_module_ansi DUT( .*);

endmodule : vunit_tb
