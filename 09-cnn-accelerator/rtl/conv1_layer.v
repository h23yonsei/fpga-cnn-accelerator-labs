`timescale 1ns / 1ps

// First convolution layer: eight 3x3 filters over the frame of three stacked 28x28 images. The
// kernels are loaded from the convolution weight memory as weights 0-71; weight_addr runs one
// ahead of weight_in, so filter f loads while weight_addr is in 9f+1 .. 9f+9. Each valid window
// produces eight results, 7 cycles later (the conv1_math latency), flagged by valid_out.
module conv1_layer #(
    parameter OUT_WIDTH  = 26,
    parameter OUT_HEIGHT = 3 * 26,
    parameter OUT_DEPTH  = OUT_WIDTH * OUT_HEIGHT
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       valid_in,

    input  wire [7:0] pixel_in,
    input  wire [7:0] weight_in,
    input  wire [6:0] weight_addr,

    output reg        valid_out,
    output wire [7:0] out_data0,
    output wire [7:0] out_data1,
    output wire [7:0] out_data2,
    output wire [7:0] out_data3,
    output wire [7:0] out_data4,
    output wire [7:0] out_data5,
    output wire [7:0] out_data6,
    output wire [7:0] out_data7,

    output reg        done
);

    // conv1_math takes this many cycles from the window to its result
    localparam CONV1_LAT = 7;

    wire       slide_full;
    wire       slide_valid;
    wire [7:0] tap0, tap1, tap2, tap3, tap4, tap5, tap6, tap7, tap8;

    conv_slide_reg u_slide (
        .clk(clk),
        .resetn(resetn),
        .en(valid_in),
        .din(pixel_in),
        .is_full(slide_full),
        .is_valid(slide_valid),
        .dout0(tap0), .dout1(tap1), .dout2(tap2),
        .dout3(tap3), .dout4(tap4), .dout5(tap5),
        .dout6(tap6), .dout7(tap7), .dout8(tap8)
    );

    wire [7:0] weight [0:71];
    wire [7:0] result [0:7];

    genvar f;
    generate
        for (f = 0; f < 8; f = f + 1) begin : gen_filter
            filter_window u_filter (
                .clk(clk),
                .resetn(resetn),
                .en(weight_addr > 9 * f && weight_addr <= 9 * f + 9),
                .data_in(weight_in),
                .weight0(weight[9*f]),   .weight1(weight[9*f+1]), .weight2(weight[9*f+2]),
                .weight3(weight[9*f+3]), .weight4(weight[9*f+4]), .weight5(weight[9*f+5]),
                .weight6(weight[9*f+6]), .weight7(weight[9*f+7]), .weight8(weight[9*f+8])
            );

            conv1_math u_math (
                .clk(clk),
                .pixel0(tap0), .pixel1(tap1), .pixel2(tap2),
                .pixel3(tap3), .pixel4(tap4), .pixel5(tap5),
                .pixel6(tap6), .pixel7(tap7), .pixel8(tap8),
                .weight0(weight[9*f]),   .weight1(weight[9*f+1]), .weight2(weight[9*f+2]),
                .weight3(weight[9*f+3]), .weight4(weight[9*f+4]), .weight5(weight[9*f+5]),
                .weight6(weight[9*f+6]), .weight7(weight[9*f+7]), .weight8(weight[9*f+8]),
                .result(result[f])
            );
        end
    endgenerate

    assign out_data0 = result[0];
    assign out_data1 = result[1];
    assign out_data2 = result[2];
    assign out_data3 = result[3];
    assign out_data4 = result[4];
    assign out_data5 = result[5];
    assign out_data6 = result[6];
    assign out_data7 = result[7];

    // valid_s / done_s are registered one cycle after the window; valid_out / done follow
    // CONV1_LAT - 1 cycles later, when conv1_math's result for that window is ready
    reg [10:0]          output_count;
    reg                 valid_s, done_s;
    reg [CONV1_LAT-2:1] valid_dl, done_dl;

    wire window_valid = slide_valid && slide_full && (output_count < OUT_DEPTH);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            output_count <= 11'd0;
            valid_s      <= 1'b0;
            done_s       <= 1'b0;
        end else begin
            valid_s <= window_valid;
            done_s  <= (output_count == OUT_DEPTH);
            if (window_valid)
                output_count <= output_count + 11'd1;
            else if (output_count == OUT_DEPTH)
                output_count <= 11'd0;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_dl  <= 0;
            done_dl   <= 0;
            valid_out <= 1'b0;
            done      <= 1'b0;
        end else begin
            valid_dl  <= {valid_dl[CONV1_LAT-3:1], valid_s};
            done_dl   <= {done_dl[CONV1_LAT-3:1], done_s};
            valid_out <= valid_dl[CONV1_LAT-2];
            done      <= done_dl[CONV1_LAT-2];
        end
    end

endmodule
