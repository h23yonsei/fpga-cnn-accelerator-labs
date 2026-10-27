`timescale 1ns / 1ps

// Testbench for relu, the return of a convolution sum to 8 bits followed by ReLU, at the 24-bit
// width Conv2 uses. Each input is compared with the course's rule computed here: drop the 10 least
// significant bits (rounding down), saturate to [-128, 127], then replace a negative value by 0.
// The inputs are both ends of the range, every sum from -2,048 to 2,048, every sum from 4 below
// 126 x 1,024 to 4 above 129 x 1,024 (saturation starts at 128 x 1,024 = 2^17), and 10,000 random
// sums. The course's data never reaches saturation, so this is where that path is checked.
module tb_relu;

    localparam IN_WIDTH = 24;

    reg  signed [IN_WIDTH-1:0] data_in;
    wire signed [7:0]          data_out;

    relu #(
        .IN_WIDTH(IN_WIDTH)
    ) dut (
        .data_in(data_in),
        .data_out(data_out)
    );

    integer errors = 0;
    integer checks = 0;
    integer i, v;

    task check(input integer value);
        integer expected;
        begin
            data_in  = value;
            expected = value >>> 10;
            if (expected > 127)  expected = 127;
            if (expected < -128) expected = -128;
            if (expected < 0)    expected = 0;
            #1;
            checks = checks + 1;
            if (data_out !== expected) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("MISMATCH relu(%0d) = %0d, expected %0d", value, data_out, expected);
            end
        end
    endtask

    initial begin
        check(-(1 << (IN_WIDTH - 1)));
        check((1 << (IN_WIDTH - 1)) - 1);
        for (v = -2048; v <= 2048; v = v + 1)
            check(v);
        for (v = 126 * 1024 - 4; v <= 129 * 1024 + 4; v = v + 1)
            check(v);
        for (i = 0; i < 10000; i = i + 1) begin
            v = $random;
            check(v >>> (32 - IN_WIDTH));
        end

        if (errors == 0)
            $display("PASS: relu matched the course's rule on %0d sums", checks);
        else
            $display("FAIL: relu, %0d of %0d sums wrong", errors, checks);
        $finish;
    end

endmodule
