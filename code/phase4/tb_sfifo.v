//==============================================================================
// tb_sfifo.v — 同步 FIFO 自检
//------------------------------------------------------------------------------
// 流程：复位 -> 连续写满 16 个数(0..15) 观察 full -> 再写应被忽略 ->
//       连续读空 观察 empty -> 校验读出顺序 0..15 -> 回环再写读一轮。
//==============================================================================
`timescale 1ns/1ps
module tb_sfifo;

    reg         clk;
    reg         rst_n;
    reg         wr_en;
    reg  [7:0]  wr_data;
    reg         rd_en;
    wire [7:0]  rd_data;
    wire        empty, full, almost_full;
    wire [4:0]  count;

    initial clk = 1'b0;
    always #10 clk = ~clk;

    sfifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data),
        .empty(empty), .full(full),
        .almost_full(almost_full), .count(count)
    );

    integer i;
    integer errors;
    integer got;
    reg     full_seen;
    reg     empty_seen;

    initial begin
        rst_n = 1'b0;
        wr_en = 1'b0; rd_en = 1'b0; wr_data = 8'd0;
        errors = 0; got = 0;
        full_seen = 0; empty_seen = 0;
        #25;
        rst_n = 1'b1;
        #20;

        // 1) 写满 16 个数
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            wr_en   = 1'b1;
            wr_data = i[7:0];
        end
        @(posedge clk);
        wr_en = 1'b0;
        if (full) full_seen = 1;

        // 写满后再写一个，应被忽略
        @(posedge clk);
        wr_en = 1'b1; wr_data = 8'hAA;
        @(posedge clk);
        wr_en = 1'b0;

        // 2) 读空 16 个数，顺序应为 0..15
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            rd_en = 1'b1;
            @(posedge clk);
            rd_en = 1'b0;
            if (rd_data !== i[7:0]) errors = errors + 1;
            got = got + 1;
        end
        if (empty) empty_seen = 1;

        // 3) 回环：再写读一轮
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            wr_en = 1'b1; wr_data = i[7:0] + 8'h20;
        end
        @(posedge clk); wr_en = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            rd_en = 1'b1;
            @(posedge clk);
            rd_en = 1'b0;
            if (rd_data !== i[7:0] + 8'h20) errors = errors + 1;
        end

        #20;
        $display("---- tb_sfifo ----");
        $display("full_seen=%0d empty_seen=%0d got=%0d errors=%0d",
                 full_seen, empty_seen, got, errors);
        if (full_seen && empty_seen && errors == 0)
            $display("TB_SFIFO: PASS");
        else
            $display("TB_SFIFO: FAIL");
        $finish;
    end

endmodule
