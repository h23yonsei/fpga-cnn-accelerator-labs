`timescale 1ns / 1ps

// Top level of the IDLE / UP / DOWN / READY controller for the Arty S7-50: clock divider, switch
// debouncers for SW0 and SW1, the controller, and a two-digit seven-segment display on Pmod ports
// JC and JD. SW3 is used directly as the controller's asynchronous reset.
module top_fsm (
    input  wire       clk_100mhz,
    input  wire       sw0,
    input  wire       sw1,
    input  wire       sw3,
    output wire [1:0] led,
    output wire [3:0] jc,
    output wire [3:0] jd
);

    wire       clk_50hz;
    wire       clk_1hz;
    wire       sw0_level;
    wire       sw1_level;
    wire [3:0] count;
    wire       seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;
    wire       digit_sel;

    clock_divider u_clock_divider (
        .clk_100mhz(clk_100mhz),
        .clk_50hz(clk_50hz),
        .clk_1hz(clk_1hz)
    );

    sw_debouncer u_sw0_debouncer (
        .clk(clk_50hz),
        .sw(sw0),
        .level(sw0_level)
    );

    sw_debouncer u_sw1_debouncer (
        .clk(clk_50hz),
        .sw(sw1),
        .level(sw1_level)
    );

    fsm_ctrl u_fsm_ctrl (
        .clk_1hz(clk_1hz),
        .clk_50hz(clk_50hz),
        .sw0(sw0_level),
        .sw1(sw1_level),
        .sw3(sw3),
        .count(count),
        .led(led)
    );

    ssd_ctrl u_ssd_ctrl (
        .clk_50hz(clk_50hz),
        .count(count),
        .seg_a(seg_a), .seg_b(seg_b), .seg_c(seg_c), .seg_d(seg_d),
        .seg_e(seg_e), .seg_f(seg_f), .seg_g(seg_g),
        .digit_sel(digit_sel)
    );

    // Pmod wiring of the display
    assign jc = {seg_d, seg_c, seg_b, seg_a};
    assign jd = {digit_sel, seg_g, seg_f, seg_e};

endmodule
