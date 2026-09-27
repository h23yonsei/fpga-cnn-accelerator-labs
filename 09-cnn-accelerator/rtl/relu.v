`timescale 1ns / 1ps

// ReLU followed by the fixed-point scaling used after each convolution: a negative sum becomes 0,
// and bits [16:10] of the sum are kept, so the result lies in 0-127.
module relu #(
    parameter IN_WIDTH = 22
)(
    input  wire signed [IN_WIDTH-1:0] data_in,
    output wire signed [7:0]          data_out
);

    wire signed [IN_WIDTH-1:0] clamped = (data_in < 0) ? {IN_WIDTH{1'b0}} : data_in;

    assign data_out = {1'b0, clamped[10 +: 7]};

endmodule
