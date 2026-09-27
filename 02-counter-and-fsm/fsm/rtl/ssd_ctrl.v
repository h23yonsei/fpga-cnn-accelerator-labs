`timescale 1ns / 1ps

// Two-digit seven-segment display driver for counts 0-15. The display is multiplexed at 50 Hz:
// digit_sel alternates between the tens and ones digits, and seg_a..seg_g drive the segments of
// the digit currently selected (active high).
module ssd_ctrl (
    input  wire       clk_50hz,
    input  wire [3:0] count,
    output reg        seg_a,
    output reg        seg_b,
    output reg        seg_c,
    output reg        seg_d,
    output reg        seg_e,
    output reg        seg_f,
    output reg        seg_g,
    output reg        digit_sel
);

    reg [3:0] tens;
    reg [3:0] ones;
    reg       show_ones = 1'b0;

    // split the count into decimal digits
    always @(*) begin
        if (count >= 4'd10) begin
            tens = 4'd1;
            ones = count - 4'd10;
        end else begin
            tens = 4'd0;
            ones = count;
        end
    end

    // alternate between the two digits
    always @(posedge clk_50hz) begin
        show_ones <= ~show_ones;
        digit_sel <= show_ones;
    end

    // segment pattern {a, b, c, d, e, f, g} for the selected digit
    always @(*) begin
        case (show_ones ? ones : tens)
            4'd0:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111110;
            4'd1:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0110000;
            4'd2:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1101101;
            4'd3:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111001;
            4'd4:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0110011;
            4'd5:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1011011;
            4'd6:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1011111;
            4'd7:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1110000;
            4'd8:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111111;
            4'd9:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1111011;
            default: {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0000000;
        endcase
    end

endmodule
