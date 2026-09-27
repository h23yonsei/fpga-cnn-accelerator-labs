`timescale 1ns / 1ps

`define CLOCK_PERIOD 10
`define DELTA 1

// Testbench for the three-row line buffer. 306 random samples are written with random gaps of 1-21
// clock cycles; once ready rises, the three rows are read back in parallel and every triple is
// compared with the samples written (row 2, row 1, row 0).
module tb_line_buffer;

    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 102;    // must match line_buffer's fixed 102-sample rows

    reg clk;
    initial begin
        clk = 1'b0;
        forever #(`CLOCK_PERIOD / 2) clk = ~clk;
    end

    reg                     resetn;
    reg                     wren_i;
    reg                     rden_i;
    reg  [DATA_WIDTH-1:0]   data_in;
    wire                    ready;
    wire [3*DATA_WIDTH-1:0] data_out;

    reg [DATA_WIDTH-1:0]   written  [0:3*FIFO_DEPTH-1];
    reg [3*DATA_WIDTH-1:0] readback [0:FIFO_DEPTH-1];

    integer i, j, k;

    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .NUM_FIFO(3)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .ready(ready),
        .wren_i(wren_i),
        .rden_i(rden_i),
        .data_in(data_in),
        .data_out_0(data_out[DATA_WIDTH-1:0]),
        .data_out_1(data_out[2*DATA_WIDTH-1:DATA_WIDTH]),
        .data_out_2(data_out[3*DATA_WIDTH-1:2*DATA_WIDTH])
    );

    initial begin
        for (i = 0; i < 3 * FIFO_DEPTH; i = i + 1)
            written[i] <= $random;
    end

    // reset
    initial begin
        resetn  = 1'b1;
        wren_i  = 1'b0;
        rden_i  = 1'b0;
        data_in = {DATA_WIDTH{1'b0}};
        @(posedge clk); #(`DELTA) resetn = 1'b0;
        @(posedge clk); #(`DELTA) resetn = 1'b1;
    end

    // write all samples with random gaps of 1-21 clock cycles
    initial begin
        #300;
        for (k = 0; k < 3 * FIFO_DEPTH; k = k + 1) begin
            #(`CLOCK_PERIOD * ($urandom % 20 + 1));
            @(posedge clk); #(`DELTA)
            wren_i  = 1'b1;
            data_in = written[k];
            @(posedge clk); #(`DELTA)
            wren_i  = 1'b0;
        end
    end

    task compare_memory;
        begin
            rden_i <= 1'b1;
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin
                @(posedge clk); #(`DELTA)
                readback[j] <= data_out;
                $display("[%0d] expected %h, got %h", j,
                         {written[2*FIFO_DEPTH+j], written[FIFO_DEPTH+j], written[j]}, data_out);
                if ({written[2*FIFO_DEPTH+j], written[FIFO_DEPTH+j], written[j]} !== data_out) begin
                    $display("FAIL: memory comparison failed at %0t ns", $time);
                    $writememh("written.hex", written);
                    $writememh("readback.hex", readback);
                    $finish;
                end
            end
            $display("PASS: memory comparison succeeded at %0t ns", $time);
        end
    endtask

    initial begin
        @(posedge ready) begin
            #(`DELTA) compare_memory;
            #(`DELTA) $finish;
        end
    end

endmodule
