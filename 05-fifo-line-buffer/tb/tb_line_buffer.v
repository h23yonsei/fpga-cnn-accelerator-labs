`timescale 1ns / 1ps

`define CLOCK_PERIOD 10
`define DELTA 1

// Testbench for the line buffer of three 8 x 8 FIFOs. In each of two passes, 24 random samples are
// written with random gaps of 2-21 clock cycles; once ready rises, one more write is attempted
// (it must be refused), the three rows are read back in parallel and every triple is compared with
// the samples written (row 2, row 1, row 0). rden_i is held two cycles past the last row so that
// ready must fall without anything more being popped, and the second pass checks that the buffer
// fills and empties correctly again.
module tb_line_buffer;

    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 8;
    localparam PASSES     = 2;
    localparam PER_PASS   = 3 * FIFO_DEPTH;

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

    reg [DATA_WIDTH-1:0]   written [0:PASSES*PER_PASS-1];
    reg [3*DATA_WIDTH-1:0] expected;

    integer errors = 0;
    integer i, j, k, p, q;

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
        .data_out(data_out)
    );

    initial begin
        for (i = 0; i < PASSES * PER_PASS; i = i + 1)
            written[i] = $random;
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

    // writer: each pass writes its samples with random gaps of 2-21 clock cycles, then tries one
    // more write while ready is high and waits until the rows have been read out
    initial begin
        #300;
        for (p = 0; p < PASSES; p = p + 1) begin
            for (k = 0; k < PER_PASS; k = k + 1) begin
                #(`CLOCK_PERIOD * ($urandom % 20 + 1));
                @(posedge clk); #(`DELTA)
                wren_i  = 1'b1;
                data_in = written[p * PER_PASS + k];
                @(posedge clk); #(`DELTA)
                wren_i  = 1'b0;
            end
            wait (ready === 1'b1);
            @(posedge clk); #(`DELTA)
            wren_i  = 1'b1;
            data_in = ~written[p * PER_PASS];
            @(posedge clk); #(`DELTA)
            wren_i  = 1'b0;
            wait (ready === 1'b0);
        end
    end

    task compare_rows(input integer pass);
        begin
            rden_i <= 1'b1;
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin
                @(posedge clk); #(`DELTA)
                expected = {written[pass * PER_PASS + 2 * FIFO_DEPTH + j],
                            written[pass * PER_PASS + FIFO_DEPTH + j],
                            written[pass * PER_PASS + j]};
                $display("[pass %0d, %0d] expected %h, got %h", pass, j, expected, data_out);
                if (data_out !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH at %0t ns", $time);
                end
            end
            @(posedge clk); #(`DELTA)
            @(posedge clk); #(`DELTA)
            rden_i <= 1'b0;
            if (ready !== 1'b0 || dut.empty_0 !== 1'b1 || dut.empty_1 !== 1'b1 ||
                dut.empty_2 !== 1'b1) begin
                errors = errors + 1;
                $display("MISMATCH: after the last row, ready=%b empty=%b%b%b, expected 0 and 111",
                         ready, dut.empty_2, dut.empty_1, dut.empty_0);
            end
        end
    endtask

    initial begin
        for (q = 0; q < PASSES; q = q + 1) begin
            @(posedge ready);
            #(`DELTA) compare_rows(q);
        end
        if (errors == 0)
            $display("PASS: memory comparison succeeded, %0d passes of %0d samples", PASSES, PER_PASS);
        else
            $display("FAIL: %0d line buffer checks failed", errors);
        $finish;
    end

endmodule
