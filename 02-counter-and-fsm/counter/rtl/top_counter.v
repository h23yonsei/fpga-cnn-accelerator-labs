`timescale 1ns / 1ps

// Top level of the 0-9 up/down counter for the Arty S7-50.
//
// BTN0 counts up and stops at 9, BTN1 counts down and stops at 0, and SW0 low resets the count
// to 0. The count is shown as two digits, 00-09, on a seven-segment display wired to Pmod ports JC
// and JD. The display is multiplexed at 50 Hz: jd[3] selects the digit, low for the ones digit
// (the count) and high for the tens digit (always 0).
module top_counter (
    input  wire       clk_100mhz,
    input  wire [1:0] btn,
    input  wire       sw,
    output wire [3:0] jc,
    output wire [3:0] jd
);

    wire      clk_50hz;
    wire      up_pulse;
    wire      down_pulse;
    reg [3:0] count     = 4'd0;
    reg       show_tens = 1'b0;
    reg       seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;

    clock_divider u_clock_divider (
        .clk_100mhz(clk_100mhz),
        .clk_50hz(clk_50hz)
    );

    btn_debouncer u_btn_up (
        .clk(clk_50hz),
        .btn(btn[0]),
        .pulse(up_pulse)
    );

    btn_debouncer u_btn_down (
        .clk(clk_50hz),
        .btn(btn[1]),
        .pulse(down_pulse)
    );

    always @(posedge clk_50hz or negedge sw) begin
        if (!sw)
            count <= 4'd0;
        else if (up_pulse && count < 4'd9)
            count <= count + 4'd1;
        else if (down_pulse && count > 4'd0)
            count <= count - 4'd1;
    end

    // alternate between the two digits
    always @(posedge clk_50hz) begin
        show_tens <= ~show_tens;
    end

    // segment pattern {a, b, c, d, e, f, g} for the selected digit
    always @(*) begin
        case (show_tens ? 4'd0 : count)
            4'd0:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111110;
            4'd1:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0110000;
            4'd2:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1101101;
            4'd3:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111001;
            4'd4:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0110011;
            4'd5:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1011011;
            4'd6:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1011111;
            4'd7:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1110000;
            4'd8:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111111;
            4'd9:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1110011;
            default: {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0000000;
        endcase
    end

    assign jc = {seg_d, seg_c, seg_b, seg_a};
    assign jd = {show_tens, seg_g, seg_f, seg_e};

endmodule
