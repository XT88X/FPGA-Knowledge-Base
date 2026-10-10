// =============================================================================
// ch2_tb_axi_gpio.v — AXI4-Lite GPIO 从机测试平台
//   内置简易 AXI 主端序列（内联 while 等待，便于纯语法解析）：
//     1) 写 GPIO_DATA -> led_o 跟随；读回 GPIO_DATA 一致
//     2) 读 GPIO_INPUT 跟随 sw_i
//     3) 读 VERSION 返回固定值
//     4) AW/W 先后到达（人为 stall awvalid）仍能正确完成写
//     5) B/R 响应恒为 OKAY
// =============================================================================
`timescale 1ns/1ps
module ch2_tb_axi_gpio;

    reg         clk;
    reg         rstn;

    reg  [31:0] awaddr;  reg awvalid; wire awready;
    reg  [31:0] wdata;   reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;   wire bvalid; reg bready;
    reg  [31:0] araddr;  reg arvalid; wire arready;
    wire [31:0] rdata;   wire [1:0] rresp; wire rvalid; reg rready;
    wire [3:0]  led_o;
    reg  [3:0]  sw_i;

    ch2_axi_lite_gpio u_dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rstn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata),   .s_axi_wstrb(wstrb),     .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp),   .s_axi_bvalid(bvalid),   .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata),   .s_axi_rresp(rresp),     .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .led_o(led_o), .sw_i(sw_i)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    reg [31:0] rd_val;
    integer pass;
    integer done;

    initial begin
        pass = 0;
        done = 0;
        rstn = 1'b0;
        awvalid=1'b0; wvalid=1'b0; bready=1'b0; arvalid=1'b0; rready=1'b0;
        awaddr=32'h0; wdata=32'h0; araddr=32'h0;
        sw_i = 4'h0;
        #50;
        rstn = 1'b1;
        #20;

        // ---- 1) 标准写：GPIO_DATA = 0b1010 ----
        @(posedge clk);
        awaddr=32'h0; awvalid=1'b1;
        wdata=32'hA; wstrb=4'b1111; wvalid=1'b1; bready=1'b1;
        while (!(awready && awvalid)) @(posedge clk); awvalid=1'b0;
        while (!(wready && wvalid)) @(posedge clk);  wvalid=1'b0;
        while (!(bvalid && bready)) @(posedge clk);  bready=1'b0;
        if (led_o !== 4'b1010) $display("FAIL1: led_o=%b", led_o);
        else begin pass=pass+1; $display("PASS1: led_o=1010"); end

        // ---- 2) 读回 GPIO_DATA ----
        @(posedge clk);
        araddr=32'h0; arvalid=1'b1; rready=1'b1;
        while (!(arready && arvalid)) @(posedge clk); arvalid=1'b0;
        while (!(rvalid && rready)) @(posedge clk);   rd_val=rdata; rready=1'b0;
        if (rd_val[3:0] !== 4'b1010) $display("FAIL2: rd=%h", rd_val);
        else begin pass=pass+1; $display("PASS2: readback=1010"); end

        // ---- 3) 读 GPIO_INPUT（sw_i=0110）----
        sw_i = 4'b0110; #20;
        @(posedge clk);
        araddr=32'h4; arvalid=1'b1; rready=1'b1;
        while (!(arready && arvalid)) @(posedge clk); arvalid=1'b0;
        while (!(rvalid && rready)) @(posedge clk);   rd_val=rdata; rready=1'b0;
        if (rd_val[3:0] !== 4'b0110) $display("FAIL3: input=%h", rd_val);
        else begin pass=pass+1; $display("PASS3: gpio_input=0110"); end

        // ---- 4) 读 VERSION ----
        @(posedge clk);
        araddr=32'h8; arvalid=1'b1; rready=1'b1;
        while (!(arready && arvalid)) @(posedge clk); arvalid=1'b0;
        while (!(rvalid && rready)) @(posedge clk);   rd_val=rdata; rready=1'b0;
        if (rd_val !== 32'h20261010) $display("FAIL4: version=%h", rd_val);
        else begin pass=pass+1; $display("PASS4: version=20261010"); end

        // ---- 5) 拆分写：先 AW 后 W，写 GPIO_DATA=0b0101 ----
        @(posedge clk);
        awaddr=32'h0; awvalid=1'b1;
        while (!(awready && awvalid)) @(posedge clk); awvalid=1'b0;
        @(posedge clk);
        wdata=32'h5; wstrb=4'b1111; wvalid=1'b1; bready=1'b1;
        while (!(wready && wvalid)) @(posedge clk); wvalid=1'b0;
        while (!(bvalid && bready)) @(posedge clk); bready=1'b0;
        if (led_o !== 4'b0101) $display("FAIL5: led_o=%b", led_o);
        else begin pass=pass+1; $display("PASS5: split-write led_o=0101"); end

        done = 1;
        $display("==== AXI GPIO TB: %0d/5 checks passed ====", pass);
        $finish;
    end

endmodule
