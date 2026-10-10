//==============================================================================
// tb_mux4.v  —  Testbench：4 选 1 MUX 自检（WIDTH=8）
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_mux4;

    reg  [7:0] d0, d1, d2, d3;
    reg  [1:0] sel;
    wire [7:0] y;
    integer err;

    mux4 #(
        .WIDTH(8)
    ) u_dut (
        .d0  (d0),
        .d1  (d1),
        .d2  (d2),
        .d3  (d3),
        .sel (sel),
        .y   (y)
    );

    initial begin
        d0  = 8'h11; d1 = 8'h22; d2 = 8'h33; d3 = 8'h44;
        sel = 2'd0; err = 0;

        sel = 2'd0; #5; if (y != 8'h11) begin err=err+1; $display("[TB] FAIL sel=0 y=%h", y); end
        sel = 2'd1; #5; if (y != 8'h22) begin err=err+1; $display("[TB] FAIL sel=1 y=%h", y); end
        sel = 2'd2; #5; if (y != 8'h33) begin err=err+1; $display("[TB] FAIL sel=2 y=%h", y); end
        sel = 2'd3; #5; if (y != 8'h44) begin err=err+1; $display("[TB] FAIL sel=3 y=%h", y); end

        if (err == 0) $display("[TB] PASS: mux4 四路选择全部正确");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
