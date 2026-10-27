`timescale 1ns / 1ps

// Multiplies a 9-bit signed pixel by a 3-bit signed kernel coefficient (-2 to 2).
module signed_mult (
    input  wire signed [8:0]  pixel,
    input  wire signed [2:0]  coeff,
    output wire signed [11:0] product
);

    assign product = pixel * coeff;

endmodule
