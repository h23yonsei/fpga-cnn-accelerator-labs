`timescale 1ns / 1ps

// Nine-term dot product for one input channel of the second convolution layer: nine registered
// multipliers (mult8x8, 3 cycles) followed by a registered 9 -> 5 -> 3 -> 2 -> 1 adder tree
// (4 cycles). Latency from pixel/weight to result is 7 cycles; conv2_layer delays its valid and
// write enable to match. Datapath registers have no reset.
module conv2_math (
    input  wire               clk,

    input  wire signed [7:0]  pixel0,
    input  wire signed [7:0]  pixel1,
    input  wire signed [7:0]  pixel2,
    input  wire signed [7:0]  pixel3,
    input  wire signed [7:0]  pixel4,
    input  wire signed [7:0]  pixel5,
    input  wire signed [7:0]  pixel6,
    input  wire signed [7:0]  pixel7,
    input  wire signed [7:0]  pixel8,

    input  wire signed [7:0]  weight0,
    input  wire signed [7:0]  weight1,
    input  wire signed [7:0]  weight2,
    input  wire signed [7:0]  weight3,
    input  wire signed [7:0]  weight4,
    input  wire signed [7:0]  weight5,
    input  wire signed [7:0]  weight6,
    input  wire signed [7:0]  weight7,
    input  wire signed [7:0]  weight8,

    output wire signed [19:0] result
);

    // multipliers: 3 cycles
    wire signed [15:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;

    mult8x8 u_mult0 (.clk(clk), .a(pixel0), .b(weight0), .p(p0));
    mult8x8 u_mult1 (.clk(clk), .a(pixel1), .b(weight1), .p(p1));
    mult8x8 u_mult2 (.clk(clk), .a(pixel2), .b(weight2), .p(p2));
    mult8x8 u_mult3 (.clk(clk), .a(pixel3), .b(weight3), .p(p3));
    mult8x8 u_mult4 (.clk(clk), .a(pixel4), .b(weight4), .p(p4));
    mult8x8 u_mult5 (.clk(clk), .a(pixel5), .b(weight5), .p(p5));
    mult8x8 u_mult6 (.clk(clk), .a(pixel6), .b(weight6), .p(p6));
    mult8x8 u_mult7 (.clk(clk), .a(pixel7), .b(weight7), .p(p7));
    mult8x8 u_mult8 (.clk(clk), .a(pixel8), .b(weight8), .p(p8));

    // adder tree: 4 cycles
    reg signed [16:0] s1_0, s1_1, s1_2, s1_3;
    reg signed [15:0] s1_4;
    reg signed [17:0] s2_0, s2_1;
    reg signed [15:0] s2_2;
    reg signed [18:0] s3_0;
    reg signed [15:0] s3_1;
    reg signed [19:0] sum;

    always @(posedge clk) begin
        s1_0 <= p0 + p1;
        s1_1 <= p2 + p3;
        s1_2 <= p4 + p5;
        s1_3 <= p6 + p7;
        s1_4 <= p8;

        s2_0 <= s1_0 + s1_1;
        s2_1 <= s1_2 + s1_3;
        s2_2 <= s1_4;

        s3_0 <= s2_0 + s2_1;
        s3_1 <= s2_2;

        sum  <= s3_0 + s3_1;
    end

    assign result = sum;

endmodule
