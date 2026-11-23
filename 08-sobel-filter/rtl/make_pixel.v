`timescale 1ns / 1ps

// Edge strength |Gx| + |Gy|, saturated to an 8-bit pixel.
module make_pixel (
    input  wire [15:0] gx_abs,
    input  wire [15:0] gy_abs,
    output wire [7:0]  pixel
);

    wire [15:0] total = gx_abs + gy_abs;

    assign pixel = (total > 16'd255) ? 8'd255 : total[7:0];

endmodule
