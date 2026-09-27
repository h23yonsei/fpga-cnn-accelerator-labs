`timescale 1ns / 1ps

// Three-row line buffer for a 3x3 window over a 102-pixel-wide image.
//
// Incoming pixels are routed to three FIFOs in turn: samples 0-101 of each 306-sample group go to
// FIFO 0, 102-203 to FIFO 1 and 204-305 to FIFO 2. Once all three FIFOs are full, ready rises and
// rden_i reads the three rows in parallel; ready falls again when all three are empty. The row
// length is fixed at 102 samples to match the Sobel image in 08-sobel-filter.
module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 102,
    parameter NUM_FIFO   = 3
) (
    input  wire                  clk,
    input  wire                  resetn,
    output wire                  ready,
    input  wire                  wren_i,
    input  wire                  rden_i,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out_0,
    output wire [DATA_WIDTH-1:0] data_out_1,
    output wire [DATA_WIDTH-1:0] data_out_2
);

    localparam ROW_LENGTH = 102;

    wire full_0, full_1, full_2;
    wire empty_0, empty_1, empty_2;

    // position within the current group of three rows selects the FIFO to write
    reg  [8:0] write_count;
    wire [1:0] row_sel = (write_count < ROW_LENGTH)     ? 2'd0 :
                         (write_count < 2 * ROW_LENGTH) ? 2'd1 : 2'd2;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            write_count <= 9'd0;
        else if (wren_i)
            write_count <= (write_count == 3 * ROW_LENGTH - 1) ? 9'd0 : write_count + 9'd1;
    end

    wire wren_0 = wren_i & (row_sel == 2'd0) & ~full_0;
    wire wren_1 = wren_i & (row_sel == 2'd1) & ~full_1;
    wire wren_2 = wren_i & (row_sel == 2'd2) & ~full_2;

    // ready: set when all rows are full, cleared when all are empty
    reg ready_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            ready_r <= 1'b0;
        else if (full_0 & full_1 & full_2)
            ready_r <= 1'b1;
        else if (empty_0 & empty_1 & empty_2)
            ready_r <= 1'b0;
    end

    assign ready = ready_r;

    wire rden_all = rden_i & ready_r;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_0 (
        .clk(clk),
        .rst_n(resetn),
        .wren_i(wren_0),
        .rden_i(rden_all),
        .wdata_i(data_in),
        .rdata_o(data_out_0),
        .full_o(full_0),
        .empty_o(empty_0)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_1 (
        .clk(clk),
        .rst_n(resetn),
        .wren_i(wren_1),
        .rden_i(rden_all),
        .wdata_i(data_in),
        .rdata_o(data_out_1),
        .full_o(full_1),
        .empty_o(empty_1)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_2 (
        .clk(clk),
        .rst_n(resetn),
        .wren_i(wren_2),
        .rden_i(rden_all),
        .wdata_i(data_in),
        .rdata_o(data_out_2),
        .full_o(full_2),
        .empty_o(empty_2)
    );

endmodule
