`timescale 1ns / 1ps

// Testbench for the IDLE / UP / DOWN / READY controller with a 0-15 counter.
//
// 1. Clock divider: the real 100 MHz clock runs until clk_50hz has completed a full period (20 ms).
//    The 1 Hz output uses the same structure with a larger terminal count and is not simulated at
//    full length.
// 2. Controller: the 100 MHz clock is stopped and clk_50hz / clk_1hz are driven directly. On every
//    1 Hz tick the count must follow the state it was in: +1 in UP (stopping at 15), -1 in DOWN
//    (stopping at 0), unchanged in READY and IDLE, and 0 whenever SW3 is low. The switch sequence
//    exercises every transition in the lab spec, including both boundaries and the SW3 reset, and
//    checks the state LEDs (01 in UP, 10 in DOWN, 00 otherwise).
module tb_top_fsm;

    reg        sw0 = 1'b0, sw1 = 1'b0, sw3 = 1'b0;
    reg        clk_100mhz = 1'b0;
    wire [3:0] jc, jd;
    wire [1:0] led;

    localparam IDLE = 2'b00, UP = 2'b01, DOWN = 2'b10, READY = 2'b11;

    integer  errors = 0, ticks = 0;
    realtime t_rise1, t_rise2;

    top_fsm dut (
        .clk_100mhz(clk_100mhz),
        .sw0(sw0), .sw1(sw1), .sw3(sw3),
        .led(led),
        .jc(jc), .jd(jd)
    );

    reg fast_clock_on = 1'b1;
    initial begin
        while (fast_clock_on) #5 clk_100mhz = ~clk_100mhz;
    end

    reg slow_clocks_on = 1'b0;
    reg clk_50hz_tb = 1'b0, clk_1hz_tb = 1'b0;
    always #10_000_000  if (slow_clocks_on) clk_50hz_tb = ~clk_50hz_tb;
    always #500_000_000 if (slow_clocks_on) clk_1hz_tb  = ~clk_1hz_tb;

    // per-tick reference model of the counter
    reg [3:0] prev_count;
    reg [1:0] prev_state;
    reg [3:0] exp_count;
    always @(posedge clk_1hz_tb) begin
        prev_count = dut.u_fsm_ctrl.count;
        prev_state = dut.u_fsm_ctrl.state;
        #1;
        if (!sw3)                    exp_count = 4'd0;
        else if (prev_state == UP)   exp_count = (prev_count == 4'd15) ? 4'd15 : prev_count + 4'd1;
        else if (prev_state == DOWN) exp_count = (prev_count == 4'd0)  ? 4'd0  : prev_count - 4'd1;
        else                         exp_count = prev_count;
        ticks = ticks + 1;
        if (dut.u_fsm_ctrl.count !== exp_count) begin
            errors = errors + 1;
            $display("MISMATCH tick %0d: state=%b count %0d -> %0d, expected %0d",
                     ticks, prev_state, prev_count, dut.u_fsm_ctrl.count, exp_count);
        end
    end

    // delays are kept below 2^31 ns: longer literals overflow Verilog's 32-bit delay
    task wait_seconds(input integer n);
        begin
            repeat (n) #1_000_000_000;
        end
    endtask

    task expect_state(input [1:0] exp_state, input [1:0] exp_led, input [8*40-1:0] what);
        begin
            if (dut.u_fsm_ctrl.state !== exp_state || led !== exp_led) begin
                errors = errors + 1;
                $display("MISMATCH %0s: state=%b led=%b count=%0d, expected state=%b led=%b",
                         what, dut.u_fsm_ctrl.state, led, dut.u_fsm_ctrl.count, exp_state, exp_led);
            end else begin
                $display("ok  %0s: state=%b led=%b count=%0d",
                         what, dut.u_fsm_ctrl.state, led, dut.u_fsm_ctrl.count);
            end
        end
    endtask

    task expect_count(input [3:0] exp, input [8*40-1:0] what);
        begin
            if (dut.u_fsm_ctrl.count !== exp) begin
                errors = errors + 1;
                $display("MISMATCH %0s: count=%0d, expected %0d", what, dut.u_fsm_ctrl.count, exp);
            end else begin
                $display("ok  %0s: count=%0d", what, exp);
            end
        end
    endtask

    reg [3:0] held;
    initial begin
        // 1. clock divider (50 Hz output)
        wait (dut.clk_50hz === 1'b0);
        @(posedge dut.clk_50hz) t_rise1 = $realtime;
        @(posedge dut.clk_50hz) t_rise2 = $realtime;
        if (t_rise2 - t_rise1 != 20_000_000) begin
            errors = errors + 1;
            $display("MISMATCH clock_divider: 50 Hz period %0t ns, expected 20 ms",
                     t_rise2 - t_rise1);
        end else begin
            $display("ok  clock_divider: 100 MHz -> 50 Hz (20 ms period)");
        end

        // 2. controller
        fast_clock_on  = 1'b0;
        slow_clocks_on = 1'b1;
        force dut.clk_50hz = clk_50hz_tb;
        force dut.clk_1hz  = clk_1hz_tb;

        sw3 = 0; sw0 = 0; sw1 = 0;
        wait_seconds(1);  expect_state(IDLE, 2'b00, "SW3 low holds IDLE");
        expect_count(0, "SW3 low holds the count at 0");

        sw3 = 1; sw0 = 1;
        wait_seconds(5);  expect_state(UP, 2'b01, "SW0 high enters UP");
        sw1 = 1;
        wait_seconds(5);  expect_state(UP, 2'b01, "SW1 does not leave UP while SW0 is high");

        sw0 = 0; sw1 = 0;
        wait_seconds(1);  expect_state(READY, 2'b00, "both switches low enters READY");
        held = dut.u_fsm_ctrl.count;
        wait_seconds(2);  expect_count(held, "READY holds the count");

        sw0 = 1; sw1 = 0;
        wait_seconds(7);  expect_state(UP, 2'b01, "UP again");
        expect_count(15, "UP stops at 15");

        sw0 = 0; sw1 = 1;
        wait_seconds(17); expect_state(DOWN, 2'b10, "SW1 high with SW0 low enters DOWN");
        expect_count(0, "DOWN stops at 0");

        sw0 = 1;
        wait_seconds(3);  expect_state(UP, 2'b01, "SW0 high leaves DOWN for UP");

        sw3 = 0;
        #1_000;           expect_count(0, "SW3 low resets the count");
        wait_seconds(3);  expect_state(IDLE, 2'b00, "SW3 low returns to IDLE");

        if (errors == 0)
            $display("PASS: FSM controller behaves as specified over %0d 1 Hz ticks", ticks);
        else
            $display("FAIL: %0d FSM controller checks failed", errors);
        $finish;
    end

endmodule
