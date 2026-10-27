`timescale 1ns / 1ps

// Classifier for one image: maxpool -> fc_layer -> argmax. The pooled pixels leave through
// maxpool_valid_out as well, so cnn_fsm can read the FC weight memories in step with them.
module maxpool_fc_argmax #(
    parameter DATA_WIDTH = 8,
    parameter PIXEL_NUM  = 2304
)(
    input  wire                         clk,
    input  wire                         resetn,
    input  wire                         start,

    // two rows of the Conv2 feature map, one column per valid clock
    input  wire signed [DATA_WIDTH-1:0] px_row0,
    input  wire signed [DATA_WIDTH-1:0] px_row1,
    input  wire                         valid_in,

    output wire                         maxpool_valid_out,

    // FC weights for the current pooled pixel
    input  wire signed [DATA_WIDTH-1:0] weight_0,
    input  wire signed [DATA_WIDTH-1:0] weight_1,
    input  wire signed [DATA_WIDTH-1:0] weight_2,
    input  wire signed [DATA_WIDTH-1:0] weight_3,
    input  wire signed [DATA_WIDTH-1:0] weight_4,
    input  wire signed [DATA_WIDTH-1:0] weight_5,
    input  wire signed [DATA_WIDTH-1:0] weight_6,
    input  wire signed [DATA_WIDTH-1:0] weight_7,
    input  wire signed [DATA_WIDTH-1:0] weight_8,
    input  wire signed [DATA_WIDTH-1:0] weight_9,

    output wire [3:0]                   argmax_out,
    output wire                         valid_out
);

    wire signed [DATA_WIDTH-1:0]        pooled;
    wire signed [DATA_WIDTH*2+12-1:0]   fc_out_0, fc_out_1, fc_out_2, fc_out_3, fc_out_4;
    wire signed [DATA_WIDTH*2+12-1:0]   fc_out_5, fc_out_6, fc_out_7, fc_out_8, fc_out_9;
    wire                                fc_valid;

    maxpool #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_maxpool (
        .clk(clk),
        .resetn(resetn),
        .px_row0(px_row0),
        .px_row1(px_row1),
        .valid_in(valid_in),
        .px_out(pooled),
        .valid_out(maxpool_valid_out)
    );

    fc_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIXEL_NUM(PIXEL_NUM)
    ) u_fc_layer (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .valid_in(maxpool_valid_out),
        .data_in(pooled),
        .weight_0(weight_0),
        .weight_1(weight_1),
        .weight_2(weight_2),
        .weight_3(weight_3),
        .weight_4(weight_4),
        .weight_5(weight_5),
        .weight_6(weight_6),
        .weight_7(weight_7),
        .weight_8(weight_8),
        .weight_9(weight_9),
        .fc_out_0(fc_out_0),
        .fc_out_1(fc_out_1),
        .fc_out_2(fc_out_2),
        .fc_out_3(fc_out_3),
        .fc_out_4(fc_out_4),
        .fc_out_5(fc_out_5),
        .fc_out_6(fc_out_6),
        .fc_out_7(fc_out_7),
        .fc_out_8(fc_out_8),
        .fc_out_9(fc_out_9),
        .valid_out(fc_valid)
    );

    argmax #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_argmax (
        .clk(clk),
        .resetn(resetn),
        .valid_in(fc_valid),
        .fc_out_0(fc_out_0),
        .fc_out_1(fc_out_1),
        .fc_out_2(fc_out_2),
        .fc_out_3(fc_out_3),
        .fc_out_4(fc_out_4),
        .fc_out_5(fc_out_5),
        .fc_out_6(fc_out_6),
        .fc_out_7(fc_out_7),
        .fc_out_8(fc_out_8),
        .fc_out_9(fc_out_9),
        .argmax_out(argmax_out),
        .valid_out(valid_out)
    );

endmodule
