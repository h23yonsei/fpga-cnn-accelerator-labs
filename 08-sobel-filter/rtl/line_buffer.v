`timescale 1ns / 1ps

// Three-row line buffer for the Sobel window.
//
// Incoming pixels are counted: the first FIFO_DEPTH samples of each group go to FIFO 0, the next
// FIFO_DEPTH to FIFO 1 and the rest to FIFO 2. ready rises once all three FIFOs are full and falls
// again when all three are empty; rden_i reads the three rows in parallel.
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
    output wire [DATA_WIDTH-1:0] data_out0,
    output wire [DATA_WIDTH-1:0] data_out1,
    output wire [DATA_WIDTH-1:0] data_out2
);

    wire full_0, full_1, full_2;
    wire empty_0, empty_1, empty_2;

    // position within the current group of three rows
    reg [8:0] count;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            count <= 9'd0;
        else if (count == FIFO_DEPTH * 3)
            count <= 9'd0;
        else if (wren_i)
            count <= count + 9'd1;
    end

    wire wren_0 = wren_i && count <= FIFO_DEPTH - 1 && !full_0;
    wire wren_1 = wren_i && count >= FIFO_DEPTH && count <= FIFO_DEPTH * 2 - 1 && !full_1;
    wire wren_2 = wren_i && count >= FIFO_DEPTH * 2 && !full_2;

    // ready: set when all rows are full, cleared when all are empty
    reg ready_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            ready_r <= 1'b0;
        else if (full_0 && full_1 && full_2)
            ready_r <= 1'b1;
        else if (empty_0 && empty_1 && empty_2)
            ready_r <= 1'b0;
    end

    assign ready = ready_r;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_0 (
        .clk(clk),
        .rst_n(resetn),
        .wren_i(wren_0),
        .rden_i(rden_i),
        .wdata_i(data_in),
        .rdata_o(data_out0),
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
        .rden_i(rden_i),
        .wdata_i(data_in),
        .rdata_o(data_out1),
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
        .rden_i(rden_i),
        .wdata_i(data_in),
        .rdata_o(data_out2),
        .full_o(full_2),
        .empty_o(empty_2)
    );

endmodule
