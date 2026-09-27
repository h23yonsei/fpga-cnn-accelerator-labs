`timescale 1ns / 1ps

// Fully connected layer, PIXEL_NUM pooled pixels -> 10 classes. Each valid pixel is registered,
// multiplied by the matching weight of every class (mult8x8, 3 cycles) and added to that class's
// running sum. After PIXEL_NUM pixels valid_out pulses; the sums then hold until start clears them
// for the next run.
module fc_layer #(
    parameter DATA_WIDTH = 8,
    parameter PIXEL_NUM  = 2304
)(
    input  wire                                clk,
    input  wire                                resetn,
    input  wire                                start,

    input  wire                                valid_in,
    input  wire signed [DATA_WIDTH-1:0]        data_in,

    input  wire signed [DATA_WIDTH-1:0]        weight_0,
    input  wire signed [DATA_WIDTH-1:0]        weight_1,
    input  wire signed [DATA_WIDTH-1:0]        weight_2,
    input  wire signed [DATA_WIDTH-1:0]        weight_3,
    input  wire signed [DATA_WIDTH-1:0]        weight_4,
    input  wire signed [DATA_WIDTH-1:0]        weight_5,
    input  wire signed [DATA_WIDTH-1:0]        weight_6,
    input  wire signed [DATA_WIDTH-1:0]        weight_7,
    input  wire signed [DATA_WIDTH-1:0]        weight_8,
    input  wire signed [DATA_WIDTH-1:0]        weight_9,

    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_0,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_1,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_2,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_3,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_4,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_5,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_6,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_7,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_8,
    output reg  signed [DATA_WIDTH*2+12-1:0]   fc_out_9,

    output reg                                 valid_out
);

    reg                         valid_in_r;
    reg signed [DATA_WIDTH-1:0] data_in_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_in_r <= 1'b0;
            data_in_r  <= 0;
        end else begin
            valid_in_r <= valid_in;
            data_in_r  <= data_in;
        end
    end

    // pixel x weight through the three-cycle multiplier; the accumulate enable is valid_in_r
    // delayed by the same three cycles
    wire signed [DATA_WIDTH*2-1:0] prod_0, prod_1, prod_2, prod_3, prod_4;
    wire signed [DATA_WIDTH*2-1:0] prod_5, prod_6, prod_7, prod_8, prod_9;

    mult8x8 u_mult0 (.clk(clk), .a(data_in_r), .b(weight_0), .p(prod_0));
    mult8x8 u_mult1 (.clk(clk), .a(data_in_r), .b(weight_1), .p(prod_1));
    mult8x8 u_mult2 (.clk(clk), .a(data_in_r), .b(weight_2), .p(prod_2));
    mult8x8 u_mult3 (.clk(clk), .a(data_in_r), .b(weight_3), .p(prod_3));
    mult8x8 u_mult4 (.clk(clk), .a(data_in_r), .b(weight_4), .p(prod_4));
    mult8x8 u_mult5 (.clk(clk), .a(data_in_r), .b(weight_5), .p(prod_5));
    mult8x8 u_mult6 (.clk(clk), .a(data_in_r), .b(weight_6), .p(prod_6));
    mult8x8 u_mult7 (.clk(clk), .a(data_in_r), .b(weight_7), .p(prod_7));
    mult8x8 u_mult8 (.clk(clk), .a(data_in_r), .b(weight_8), .p(prod_8));
    mult8x8 u_mult9 (.clk(clk), .a(data_in_r), .b(weight_9), .p(prod_9));

    reg  [3:1] valid_dl;
    wire       acc_valid = valid_dl[3];

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            valid_dl <= 3'b000;
        else
            valid_dl <= {valid_dl[2:1], valid_in_r};
    end

    reg [15:0] pixel_count;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pixel_count <= 16'd0;
            valid_out   <= 1'b0;
            fc_out_0    <= 0;
            fc_out_1    <= 0;
            fc_out_2    <= 0;
            fc_out_3    <= 0;
            fc_out_4    <= 0;
            fc_out_5    <= 0;
            fc_out_6    <= 0;
            fc_out_7    <= 0;
            fc_out_8    <= 0;
            fc_out_9    <= 0;
        end else begin
            valid_out <= 1'b0;

            if (acc_valid) begin
                fc_out_0 <= fc_out_0 + prod_0;
                fc_out_1 <= fc_out_1 + prod_1;
                fc_out_2 <= fc_out_2 + prod_2;
                fc_out_3 <= fc_out_3 + prod_3;
                fc_out_4 <= fc_out_4 + prod_4;
                fc_out_5 <= fc_out_5 + prod_5;
                fc_out_6 <= fc_out_6 + prod_6;
                fc_out_7 <= fc_out_7 + prod_7;
                fc_out_8 <= fc_out_8 + prod_8;
                fc_out_9 <= fc_out_9 + prod_9;

                if (pixel_count == PIXEL_NUM - 1) begin
                    valid_out   <= 1'b1;
                    pixel_count <= 16'd0;
                end else begin
                    pixel_count <= pixel_count + 16'd1;
                end
            end else if (start) begin
                fc_out_0 <= 0;
                fc_out_1 <= 0;
                fc_out_2 <= 0;
                fc_out_3 <= 0;
                fc_out_4 <= 0;
                fc_out_5 <= 0;
                fc_out_6 <= 0;
                fc_out_7 <= 0;
                fc_out_8 <= 0;
                fc_out_9 <= 0;
            end
        end
    end

endmodule
