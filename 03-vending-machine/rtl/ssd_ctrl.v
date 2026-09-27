`timescale 1ns / 1ps

// Two-digit seven-segment display driver. In filling mode it shows the stock of the item filled
// last; in coin and selling modes it shows the balance; otherwise it shows 0. The display is
// multiplexed at 50 Hz: digit_sel alternates between the tens and ones digits, and seg_a..seg_g
// drive the segments of the selected digit (active high, all off while SW3 is low).
module ssd_ctrl (
    input  wire       clk_50hz,
    input  wire       sw3,
    input  wire [1:0] mode,
    input  wire [7:0] balance,
    input  wire [2:0] stock1,
    input  wire [2:0] stock2,
    input  wire [2:0] stock3,
    input  wire [1:0] last_filled_item,
    output reg        seg_a,
    output reg        seg_b,
    output reg        seg_c,
    output reg        seg_d,
    output reg        seg_e,
    output reg        seg_f,
    output reg        seg_g,
    output reg        digit_sel
);

    localparam MODE_COIN = 2'b01;
    localparam MODE_SELL = 2'b10;
    localparam MODE_FILL = 2'b11;

    reg [3:0] tens;
    reg [3:0] ones;
    reg [7:0] value;
    reg       show_ones = 1'b0;

    // alternate between the two digits
    always @(posedge clk_50hz) begin
        show_ones <= ~show_ones;
        digit_sel <= show_ones;
    end

    // value to display
    always @(*) begin
        case (mode)
            MODE_FILL: begin
                case (last_filled_item)
                    2'd1:    value = stock1;
                    2'd2:    value = stock2;
                    2'd3:    value = stock3;
                    default: value = 8'd0;
                endcase
            end
            MODE_COIN, MODE_SELL: value = balance;
            default:              value = 8'd0;
        endcase
    end

    // split the value into decimal digits
    always @(*) begin
        tens = value / 8'd10;
        ones = value - tens * 8'd10;
    end

    // segment pattern {a, b, c, d, e, f, g} for the selected digit
    always @(*) begin
        if (!sw3) begin
            {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0000000;
        end else begin
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
                4'd9:    {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b1110011;
                default: {seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g} = 7'b0000000;
            endcase
        end
    end

endmodule
