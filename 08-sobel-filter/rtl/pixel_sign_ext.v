`timescale 1ns / 1ps

// Widens an unsigned 8-bit pixel to a non-negative 9-bit signed value.
module pixel_sign_ext (
    input  wire        [7:0] pixel,
    output wire signed [8:0] extended
);

    assign extended = {1'b0, pixel};

endmodule
