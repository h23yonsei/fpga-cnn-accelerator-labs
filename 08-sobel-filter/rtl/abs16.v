`timescale 1ns / 1ps

// Magnitude of a 16-bit signed value.
module abs16 (
    input  wire signed [15:0] value,
    output wire        [15:0] magnitude
);

    assign magnitude = (value < 0) ? -value : value;

endmodule
