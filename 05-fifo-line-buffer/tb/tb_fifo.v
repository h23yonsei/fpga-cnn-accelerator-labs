`timescale 1ns / 1ps

`define CLOCK_PERIOD 10
`define DELTA 1

// Testbench for the FIFO at depth 8: reset, write 0..FIFO_DEPTH-1, confirm full_o, read everything
// back in order (the block RAM read has one cycle of latency), and confirm empty_o.
module tb_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 8
);

    reg                   clk;
    reg                   rst_n;
    reg                   wren_i;
    reg                   rden_i;
    reg  [DATA_WIDTH-1:0] wdata_i;
    wire [DATA_WIDTH-1:0] rdata_o;
    wire                  full_o;
    wire                  empty_o;

    integer errors = 0;
    integer reads  = 0;
    integer i;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wren_i(wren_i),
        .rden_i(rden_i),
        .wdata_i(wdata_i),
        .rdata_o(rdata_o),
        .full_o(full_o),
        .empty_o(empty_o)
    );

    initial begin
        clk = 1'b0;
        forever #(`CLOCK_PERIOD / 2) clk = ~clk;
    end

    // every clock edge with rden_i high returns the next value, one cycle later
    always @(posedge clk) begin
        if (rst_n && rden_i) begin
            #(`DELTA);
            if (rdata_o !== reads[DATA_WIDTH-1:0]) begin
                errors = errors + 1;
                $display("MISMATCH read %0d: got %0d, expected %0d", reads, rdata_o, reads);
            end
            reads = reads + 1;
        end
    end

    initial begin
        rst_n   = 1'b1;
        wren_i  = 1'b0;
        rden_i  = 1'b0;
        wdata_i = {DATA_WIDTH{1'b0}};

        // reset
        @(posedge clk); #(`DELTA) rst_n = 1'b0;
        @(posedge clk); #(`DELTA) rst_n = 1'b1;
        if (empty_o !== 1'b1 || full_o !== 1'b0) begin
            errors = errors + 1;
            $display("MISMATCH after reset: empty=%b full=%b", empty_o, full_o);
        end

        // write 0..FIFO_DEPTH-1
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            @(posedge clk); #(`DELTA)
            wren_i  = 1'b1;
            wdata_i = i;
        end
        @(posedge clk); #(`DELTA) wren_i = 1'b0;
        if (full_o !== 1'b1 || empty_o !== 1'b0) begin
            errors = errors + 1;
            $display("MISMATCH after %0d writes: full=%b empty=%b", FIFO_DEPTH, full_o, empty_o);
        end

        // read everything back
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            @(posedge clk); #(`DELTA) rden_i = 1'b1;
        end
        @(posedge clk); #(`DELTA) rden_i = 1'b0;
        #(`CLOCK_PERIOD * 2);

        if (empty_o !== 1'b1 || full_o !== 1'b0) begin
            errors = errors + 1;
            $display("MISMATCH after reading everything: empty=%b full=%b", empty_o, full_o);
        end
        if (reads != FIFO_DEPTH) begin
            errors = errors + 1;
            $display("MISMATCH: %0d reads, expected %0d", reads, FIFO_DEPTH);
        end
        if (errors == 0)
            $display("PASS: FIFO returned %0d values in order with correct full/empty flags",
                     reads);
        else
            $display("FAIL: %0d FIFO checks failed", errors);
        $finish;
    end

endmodule
