//==============================================================================
// tb_afifo.v — 异步 FIFO 跨时钟域自检
//------------------------------------------------------------------------------
// 写时钟 wr_clk 周期 20ns，读时钟 rd_clk 周期 40ns（两个不同频率时钟域）。
// 写侧连续写入 16 个数(0..15)，读侧以慢时钟逐个读出，校验数据完整性与顺序。
//==============================================================================
`timescale 1ns/1ps
module tb_afifo;

    reg         wr_clk, rd_clk;
    reg         wr_rst_n, rd_rst_n;
    reg         wr_en;
    reg  [7:0]  wr_data;
    wire        wr_full;
    reg         rd_en;
    wire [7:0]  rd_data;
    wire        rd_empty;

    initial wr_clk = 1'b0;
    always #10 wr_clk = ~wr_clk;     // 50MHz

    initial rd_clk = 1'b0;
    always #20 rd_clk = ~rd_clk;     // 25MHz

    afifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) dut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .wr_full(wr_full),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_n),
        .rd_en(rd_en), .rd_data(rd_data), .rd_empty(rd_empty)
    );

    integer i;
    integer errors;
    integer got;

    initial begin
        wr_rst_n = 1'b0; rd_rst_n = 1'b0;
        wr_en = 1'b0; rd_en = 1'b0; wr_data = 8'd0;
        errors = 0; got = 0;
        #50;
        wr_rst_n = 1'b1; rd_rst_n = 1'b1;
        #50;

        // 写侧：16 个数，遇到 full 就等一拍
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge wr_clk);
            wr_en   = 1'b1;
            wr_data = i[7:0];
        end
        @(posedge wr_clk);
        wr_en = 1'b0;

        // 等写指针格雷码同步到读域
        #200;

        // 读侧：非空就读，先采样 rd_data 再推进指针
        for (i = 0; i < 16; i = i + 1) begin
            // 等待非空
            while (rd_empty) @(posedge rd_clk);
            @(posedge rd_clk);
            if (rd_data !== i[7:0]) errors = errors + 1;
            got = got + 1;
            rd_en = 1'b1;
            @(posedge rd_clk);
            rd_en = 1'b0;
        end

        #200;
        $display("---- tb_afifo ----");
        $display("got=%0d errors=%0d rd_empty=%0d", got, errors, rd_empty);
        if (got == 16 && errors == 0)
            $display("TB_AFIFO: PASS");
        else
            $display("TB_AFIFO: FAIL");
        $finish;
    end

endmodule
