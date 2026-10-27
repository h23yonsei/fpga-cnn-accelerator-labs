`timescale 1ns / 1ps

// Sliding 3x3 window over a raster-scanned frame of three stacked images. Every enabled clock
// shifts one pixel into a REG_DEPTH-long shift register, and the window taps are three pixels from
// each of three consecutive rows. Once the register has filled, column and row pointers follow the
// scan, and is_valid is high only where the window lies inside a single image: the columns past
// OUTPUT_WIDTH and the last two rows of each image are skipped. Dropping en clears everything.
module conv_slide_reg #(
    parameter INPUT_WIDTH  = 28,
    parameter INPUT_HEIGHT = 3 * INPUT_WIDTH,
    parameter OUTPUT_WIDTH = 26,
    parameter REG_DEPTH    = 72
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       en,
    input  wire [7:0] din,

    output reg        is_full,
    output wire       is_valid,

    // window taps, row-major
    output wire [7:0] dout0,
    output wire [7:0] dout1,
    output wire [7:0] dout2,
    output wire [7:0] dout3,
    output wire [7:0] dout4,
    output wire [7:0] dout5,
    output wire [7:0] dout6,
    output wire [7:0] dout7,
    output wire [7:0] dout8
);

    reg [7:0] shift_reg [0:REG_DEPTH-1];

    reg [$clog2(REG_DEPTH+1):0]  din_count;
    reg [$clog2(INPUT_WIDTH):0]  col_ptr;
    reg [$clog2(INPUT_HEIGHT):0] row_ptr;

    integer i;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (i = 0; i < REG_DEPTH; i = i + 1)
                shift_reg[i] <= 8'd0;
            din_count <= 0;
            col_ptr   <= 0;
            row_ptr   <= 0;
            is_full   <= 1'b0;
        end else if (en) begin
            for (i = 0; i < REG_DEPTH - 1; i = i + 1)
                shift_reg[i] <= shift_reg[i + 1];
            shift_reg[REG_DEPTH - 1] <= din;

            if (!is_full) begin
                // count pixels until the register is full
                din_count <= din_count + 1;
                if (din_count == REG_DEPTH - 1)
                    is_full <= 1'b1;
            end else begin
                // then follow the scan position
                if (col_ptr < INPUT_WIDTH - 1) begin
                    col_ptr <= col_ptr + 1;
                end else if (col_ptr == INPUT_WIDTH - 1) begin
                    col_ptr <= 0;
                    if (row_ptr < INPUT_HEIGHT - 1)
                        row_ptr <= row_ptr + 1;
                end
            end
        end else begin
            for (i = 0; i < REG_DEPTH; i = i + 1)
                shift_reg[i] <= 8'd0;
            din_count <= 0;
            col_ptr   <= 0;
            row_ptr   <= 0;
            is_full   <= 1'b0;
        end
    end

    assign is_valid = is_full
                   && (col_ptr < OUTPUT_WIDTH)
                   && (row_ptr != INPUT_HEIGHT / 3 - 2)
                   && (row_ptr != INPUT_HEIGHT / 3 - 1)
                   && (row_ptr != INPUT_HEIGHT * 2 / 3 - 2)
                   && (row_ptr != INPUT_HEIGHT * 2 / 3 - 1)
                   && (row_ptr != INPUT_HEIGHT - 2)
                   && (row_ptr != INPUT_HEIGHT - 1);

    // The taps are not zeroed outside valid positions: both layers store a result only when
    // valid, so a zeroing mux would only lengthen the path into the multipliers.
    assign dout0 = shift_reg[0];
    assign dout1 = shift_reg[1];
    assign dout2 = shift_reg[2];
    assign dout3 = shift_reg[INPUT_WIDTH];
    assign dout4 = shift_reg[INPUT_WIDTH + 1];
    assign dout5 = shift_reg[INPUT_WIDTH + 2];
    assign dout6 = shift_reg[2 * INPUT_WIDTH];
    assign dout7 = shift_reg[2 * INPUT_WIDTH + 1];
    assign dout8 = shift_reg[2 * INPUT_WIDTH + 2];

endmodule
