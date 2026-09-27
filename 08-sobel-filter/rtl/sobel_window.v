`timescale 1ns / 1ps

// 3x3 Sobel edge-strength datapath.
//
// Every ready cycle shifts one column of three pixels (one per row) into the window. The window is
// filtered with the Sobel kernels Kx and Ky, and the output is |Gx| + |Gy| saturated to 255.
//
// The two gradient sums are registered: edge_out appears one cycle after its window and is flagged
// by result_valid. valid marks a full window in the cycle it fills, a cycle ahead of result_valid;
// memory_ctrlr uses it to pace reads from the line buffer.
module sobel_window #(
    parameter DATA_WIDTH = 8
) (
    input  wire                  clk,
    input  wire                  resetn,
    input  wire [DATA_WIDTH-1:0] data_in0,          // row 0 pixel
    input  wire [DATA_WIDTH-1:0] data_in1,          // row 1 pixel
    input  wire [DATA_WIDTH-1:0] data_in2,          // row 2 pixel
    input  wire                  ready,             // a new column is available
    output wire [DATA_WIDTH-1:0] edge_out,
    output wire                  valid,             // the window is full
    output wire                  result_valid       // edge_out is valid (valid, one cycle later)
);

    // Sobel kernels, indexed [row][column]
    localparam signed [2:0] KX00 = -1, KX01 = 0, KX02 = 1;
    localparam signed [2:0] KX10 = -2, KX11 = 0, KX12 = 2;
    localparam signed [2:0] KX20 = -1, KX21 = 0, KX22 = 1;
    localparam signed [2:0] KY00 = -1, KY01 = -2, KY02 = -1;
    localparam signed [2:0] KY10 =  0, KY11 =  0, KY12 =  0;
    localparam signed [2:0] KY20 =  1, KY21 =  2, KY22 =  1;

    // ------------------------------------------------------------------------------------------
    // window

    reg [6:0] ready_count;
    reg [7:0] window [0:2][0:2];        // column 2 holds the newest pixels

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            ready_count <= 7'd0;
        else if (ready)
            ready_count <= ready_count + 7'd1;
        else
            ready_count <= 7'd0;
    end

    // one cycle of FIFO read latency plus three columns to fill the window
    assign valid = (ready_count >= 4);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            window[0][0] <= 8'd0; window[0][1] <= 8'd0; window[0][2] <= 8'd0;
            window[1][0] <= 8'd0; window[1][1] <= 8'd0; window[1][2] <= 8'd0;
            window[2][0] <= 8'd0; window[2][1] <= 8'd0; window[2][2] <= 8'd0;
        end else if (ready) begin
            window[0][0] <= window[0][1]; window[0][1] <= window[0][2]; window[0][2] <= data_in0;
            window[1][0] <= window[1][1]; window[1][1] <= window[1][2]; window[1][2] <= data_in1;
            window[2][0] <= window[2][1]; window[2][1] <= window[2][2]; window[2][2] <= data_in2;
        end
    end

    // ------------------------------------------------------------------------------------------
    // gradients

    wire signed [8:0]  pixel   [0:2][0:2];
    wire signed [11:0] gx_term [0:2][0:2];
    wire signed [11:0] gy_term [0:2][0:2];
    wire signed [15:0] gx_sum;
    wire signed [15:0] gy_sum;

    pixel_sign_ext u_ext00 (.pixel(window[0][0]), .extended(pixel[0][0]));
    pixel_sign_ext u_ext01 (.pixel(window[0][1]), .extended(pixel[0][1]));
    pixel_sign_ext u_ext02 (.pixel(window[0][2]), .extended(pixel[0][2]));
    pixel_sign_ext u_ext10 (.pixel(window[1][0]), .extended(pixel[1][0]));
    pixel_sign_ext u_ext11 (.pixel(window[1][1]), .extended(pixel[1][1]));
    pixel_sign_ext u_ext12 (.pixel(window[1][2]), .extended(pixel[1][2]));
    pixel_sign_ext u_ext20 (.pixel(window[2][0]), .extended(pixel[2][0]));
    pixel_sign_ext u_ext21 (.pixel(window[2][1]), .extended(pixel[2][1]));
    pixel_sign_ext u_ext22 (.pixel(window[2][2]), .extended(pixel[2][2]));

    signed_mult u_gx00 (.pixel(pixel[0][0]), .coeff(KX00), .product(gx_term[0][0]));
    signed_mult u_gx01 (.pixel(pixel[0][1]), .coeff(KX01), .product(gx_term[0][1]));
    signed_mult u_gx02 (.pixel(pixel[0][2]), .coeff(KX02), .product(gx_term[0][2]));
    signed_mult u_gx10 (.pixel(pixel[1][0]), .coeff(KX10), .product(gx_term[1][0]));
    signed_mult u_gx11 (.pixel(pixel[1][1]), .coeff(KX11), .product(gx_term[1][1]));
    signed_mult u_gx12 (.pixel(pixel[1][2]), .coeff(KX12), .product(gx_term[1][2]));
    signed_mult u_gx20 (.pixel(pixel[2][0]), .coeff(KX20), .product(gx_term[2][0]));
    signed_mult u_gx21 (.pixel(pixel[2][1]), .coeff(KX21), .product(gx_term[2][1]));
    signed_mult u_gx22 (.pixel(pixel[2][2]), .coeff(KX22), .product(gx_term[2][2]));

    signed_mult u_gy00 (.pixel(pixel[0][0]), .coeff(KY00), .product(gy_term[0][0]));
    signed_mult u_gy01 (.pixel(pixel[0][1]), .coeff(KY01), .product(gy_term[0][1]));
    signed_mult u_gy02 (.pixel(pixel[0][2]), .coeff(KY02), .product(gy_term[0][2]));
    signed_mult u_gy10 (.pixel(pixel[1][0]), .coeff(KY10), .product(gy_term[1][0]));
    signed_mult u_gy11 (.pixel(pixel[1][1]), .coeff(KY11), .product(gy_term[1][1]));
    signed_mult u_gy12 (.pixel(pixel[1][2]), .coeff(KY12), .product(gy_term[1][2]));
    signed_mult u_gy20 (.pixel(pixel[2][0]), .coeff(KY20), .product(gy_term[2][0]));
    signed_mult u_gy21 (.pixel(pixel[2][1]), .coeff(KY21), .product(gy_term[2][1]));
    signed_mult u_gy22 (.pixel(pixel[2][2]), .coeff(KY22), .product(gy_term[2][2]));

    adder9 u_gx_sum (
        .in0(gx_term[0][0]), .in1(gx_term[0][1]), .in2(gx_term[0][2]),
        .in3(gx_term[1][0]), .in4(gx_term[1][1]), .in5(gx_term[1][2]),
        .in6(gx_term[2][0]), .in7(gx_term[2][1]), .in8(gx_term[2][2]),
        .sum(gx_sum)
    );

    adder9 u_gy_sum (
        .in0(gy_term[0][0]), .in1(gy_term[0][1]), .in2(gy_term[0][2]),
        .in3(gy_term[1][0]), .in4(gy_term[1][1]), .in5(gy_term[1][2]),
        .in6(gy_term[2][0]), .in7(gy_term[2][1]), .in8(gy_term[2][2]),
        .sum(gy_sum)
    );

    // ------------------------------------------------------------------------------------------
    // pipeline register, then |Gx| + |Gy|
    //
    // Without this register the window, multiplies, adder trees, absolute values, saturation and
    // the bram2 write were one 13.6 ns path, which cannot meet the 100 MHz clock.

    reg signed [15:0] gx_sum_q;
    reg signed [15:0] gy_sum_q;
    reg               valid_q;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            gx_sum_q <= 16'd0;
            gy_sum_q <= 16'd0;
            valid_q  <= 1'b0;
        end else begin
            gx_sum_q <= gx_sum;
            gy_sum_q <= gy_sum;
            valid_q  <= valid;
        end
    end

    assign result_valid = valid_q;

    wire [15:0] gx_abs;
    wire [15:0] gy_abs;

    abs16 u_gx_abs (.value(gx_sum_q), .magnitude(gx_abs));
    abs16 u_gy_abs (.value(gy_sum_q), .magnitude(gy_abs));

    make_pixel u_make_pixel (
        .gx_abs(gx_abs),
        .gy_abs(gy_abs),
        .pixel(edge_out)
    );

endmodule
