`timescale 1ns / 1ps

// ArgMax over the ten FC logits. Each FC sum is first returned to 8 bits as the course specifies
// for every layer (the 10 least significant bits dropped, the result saturated to [-128, 127]),
// and the logits play a tournament split over two registered rounds. fc_layer holds the sums from
// its valid_out pulse until the next run, so the rounds register every cycle and the final two
// matches are resolved into argmax_out when valid_in has passed through both.
//
// argmax_out and valid_out update three clock edges after valid_in. In every match the
// lower-index side wins a tie, so the lowest index among equal maxima is returned.
module argmax #(
    parameter DATA_WIDTH = 8
)(
    input  wire                              clk,
    input  wire                              resetn,
    input  wire                              valid_in,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_0,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_1,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_2,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_3,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_4,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_5,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_6,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_7,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_8,
    input  wire signed [DATA_WIDTH*2+12-1:0] fc_out_9,
    output reg  [3:0]                        argmax_out,
    output reg                               valid_out
);

    localparam SUM_WIDTH = DATA_WIDTH * 2 + 12;

    // FC sum -> 8-bit logit: sum >>> 10 when that fits in [-128, 127], that is when bits
    // [SUM_WIDTH-1:17] of the sum are all equal; otherwise the bound on the sum's side
    function [7:0] logit;
        input [SUM_WIDTH-1:0] s;
        begin
            if (&s[SUM_WIDTH-1:17] || ~|s[SUM_WIDTH-1:17])
                logit = s[17:10];
            else if (s[SUM_WIDTH-1])
                logit = 8'h80;      // -128
            else
                logit = 8'h7F;      // 127
        end
    endfunction

    // {index, logit} pairs: b replaces a only if its logit is strictly greater
    function [11:0] pick;
        input [11:0] a, b;
        begin
            pick = ($signed(b[7:0]) > $signed(a[7:0])) ? b : a;
        end
    endfunction

    // round 1, registered: (0,1) (2,3) (4,5) (6,7) (8,9)
    reg [11:0] round1_0, round1_1, round1_2, round1_3, round1_4;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            round1_0 <= 0;
            round1_1 <= 0;
            round1_2 <= 0;
            round1_3 <= 0;
            round1_4 <= 0;
        end else begin
            round1_0 <= pick({4'd0, logit(fc_out_0)}, {4'd1, logit(fc_out_1)});
            round1_1 <= pick({4'd2, logit(fc_out_2)}, {4'd3, logit(fc_out_3)});
            round1_2 <= pick({4'd4, logit(fc_out_4)}, {4'd5, logit(fc_out_5)});
            round1_3 <= pick({4'd6, logit(fc_out_6)}, {4'd7, logit(fc_out_7)});
            round1_4 <= pick({4'd8, logit(fc_out_8)}, {4'd9, logit(fc_out_9)});
        end
    end

    // round 2, registered; round1_4 has a bye
    reg [11:0] round2_0, round2_1, round2_2;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            round2_0 <= 0;
            round2_1 <= 0;
            round2_2 <= 0;
        end else begin
            round2_0 <= pick(round1_0, round1_1);
            round2_1 <= pick(round1_2, round1_3);
            round2_2 <= round1_4;
        end
    end

    // rounds 3 and 4
    wire [11:0] round3 = pick(round2_0, round2_1);
    wire [11:0] winner = pick(round3, round2_2);

    reg valid_in_d1, valid_in_d2;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_in_d1 <= 1'b0;
            valid_in_d2 <= 1'b0;
            valid_out   <= 1'b0;
            argmax_out  <= 4'd0;
        end else begin
            valid_in_d1 <= valid_in;
            valid_in_d2 <= valid_in_d1;
            valid_out   <= valid_in_d2;
            if (valid_in_d2)
                argmax_out <= winner[11:8];
        end
    end

endmodule
