`timescale 1ns / 1ps

// Return of a convolution sum to 8 bits, as the course specifies for every layer, followed by
// ReLU: the 10 least significant bits are dropped and the result saturated to [-128, 127], then a
// negative value becomes 0. Combined, a negative sum gives 0, a sum of 2^17 or more gives 127, and
// any other sum gives bits [16:10].
module relu #(
    parameter IN_WIDTH = 22
)(
    input  wire signed [IN_WIDTH-1:0] data_in,
    output wire signed [7:0]          data_out
);

    assign data_out = (data_in < 0)              ? 8'sd0   :
                      (|data_in[IN_WIDTH-1:17]) ? 8'sd127 :
                                                  {1'b0, data_in[16:10]};

endmodule
