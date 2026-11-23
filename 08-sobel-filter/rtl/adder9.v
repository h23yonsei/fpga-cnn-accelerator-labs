`timescale 1ns / 1ps

// Nine-input signed adder, purely combinational: in0-in7 are summed in a balanced tree and in8 is
// added last.
module adder9 (
    input  wire signed [11:0] in0,
    input  wire signed [11:0] in1,
    input  wire signed [11:0] in2,
    input  wire signed [11:0] in3,
    input  wire signed [11:0] in4,
    input  wire signed [11:0] in5,
    input  wire signed [11:0] in6,
    input  wire signed [11:0] in7,
    input  wire signed [11:0] in8,
    output wire signed [15:0] sum
);

    wire signed [12:0] pair0 = in0 + in1;
    wire signed [12:0] pair1 = in2 + in3;
    wire signed [12:0] pair2 = in4 + in5;
    wire signed [12:0] pair3 = in6 + in7;

    wire signed [13:0] quad0 = pair0 + pair1;
    wire signed [13:0] quad1 = pair2 + pair3;

    wire signed [14:0] octet = quad0 + quad1;

    assign sum = octet + in8;

endmodule
