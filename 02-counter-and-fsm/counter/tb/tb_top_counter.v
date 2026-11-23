`timescale 1ns / 1ps

// Testbench for the 0-9 up/down counter.
//
// 1. Clock divider: the real 100 MHz clock runs until clk_50hz has completed a full period, which
//    must be 20 ms.
// 2. Counter: the 100 MHz clock is then stopped and clk_50hz is driven directly at 50 Hz, so the
//    button sequence (seconds of simulated time) runs quickly. The checks follow the lab spec:
//    BTN0 counts up and stops at 9, BTN1 counts down and stops at 0, SW0 low resets to 0, and the
//    two-digit display shows the count as 00-09: the ones digit (jd[3] low) shows the count and
//    the tens digit (jd[3] high) shows 0.
module tb_top_counter;

    reg  [1:0] btn        = 2'b00;
    reg        clk_100mhz = 1'b0;
    reg        sw         = 1'b0;
    wire [3:0] jc, jd;
    reg  [3:0] display_digit;

    integer  errors = 0;
    realtime t_rise1, t_rise2;

    top_counter dut (
        .clk_100mhz(clk_100mhz),
        .btn(btn),
        .sw(sw),
        .jc(jc),
        .jd(jd)
    );

    // segment pattern of the selected digit -> digit, same encoding as top_counter.v
    always @(*) begin
        case ({jc, jd[2:0]})
            7'b1111_011: display_digit = 4'd0;
            7'b0110_000: display_digit = 4'd1;
            7'b1011_101: display_digit = 4'd2;
            7'b1111_100: display_digit = 4'd3;
            7'b0110_110: display_digit = 4'd4;
            7'b1101_110: display_digit = 4'd5;
            7'b1101_111: display_digit = 4'd6;
            7'b0111_000: display_digit = 4'd7;
            7'b1111_111: display_digit = 4'd8;
            7'b0111_110: display_digit = 4'd9;
            default:     display_digit = 4'hF;
        endcase
    end

    // 100 MHz board clock, stopped once the divider has been checked
    reg fast_clock_on = 1'b1;
    initial begin
        while (fast_clock_on) #5 clk_100mhz = ~clk_100mhz;
    end

    // directly driven 50 Hz clock for the behavioral checks
    reg slow_clock_on = 1'b0;
    reg clk_50hz_tb   = 1'b0;
    always #10_000_000 if (slow_clock_on) clk_50hz_tb = ~clk_50hz_tb;

    // The display changes digit on every 50 Hz edge; each digit is read once.
    task expect_count(input [3:0] exp, input [8*48-1:0] what);
        reg [3:0] ones_shown, tens_shown;
        begin
            wait (jd[3] === 1'b0) #1 ones_shown = display_digit;
            wait (jd[3] === 1'b1) #1 tens_shown = display_digit;
            if (dut.count !== exp || ones_shown !== exp || tens_shown !== 4'd0) begin
                errors = errors + 1;
                $display("MISMATCH %0s: count=%0d display=%0d%0d, expected %0d",
                         what, dut.count, tens_shown, ones_shown, exp);
            end else begin
                $display("ok  %0s: %0d (display 0%0d)", what, exp, exp);
            end
        end
    endtask

    task press(input integer index);
        begin
            btn[index] = 1'b1; #20_000_000;
            btn[index] = 1'b0; #20_000_000;
        end
    endtask

    initial begin
        // 1. clock divider
        wait (dut.clk_50hz === 1'b0);
        @(posedge dut.clk_50hz) t_rise1 = $realtime;
        @(posedge dut.clk_50hz) t_rise2 = $realtime;
        if (t_rise2 - t_rise1 != 20_000_000) begin
            errors = errors + 1;
            $display("MISMATCH clock_divider: period %0t ns, expected 20 ms", t_rise2 - t_rise1);
        end else begin
            $display("ok  clock_divider: 100 MHz -> 50 Hz (20 ms period)");
        end

        // 2. counter behavior at 50 Hz
        fast_clock_on = 1'b0;
        slow_clock_on = 1'b1;
        force dut.clk_50hz = clk_50hz_tb;

        sw = 1'b0; #40_000_000;
        expect_count(0, "SW0 low holds the counter in reset");
        sw = 1'b1; #40_000_000;

        repeat (11) press(0);
        #40_000_000; expect_count(9, "11 presses of BTN0 stop at 9");
        repeat (11) press(1);
        #40_000_000; expect_count(0, "11 presses of BTN1 stop at 0");
        repeat (2) press(0);
        #40_000_000; expect_count(2, "2 presses of BTN0 count 2");
        sw = 1'b0; #1_000;
        expect_count(0, "SW0 low resets the count");

        if (errors == 0)
            $display("PASS: counter and clock divider behave as specified");
        else
            $display("FAIL: %0d counter checks failed", errors);
        $finish;
    end

endmodule
