`timescale 1ns / 1ps

// Line buffer for a 3x3 window: three FIFOs of FIFO_DEPTH samples, one per image row.
//
// While ready is low, each written sample goes into the first FIFO that is not yet full, so the
// first FIFO_DEPTH samples fill FIFO 0, the next FIFO_DEPTH FIFO 1 and the last FIFO_DEPTH FIFO 2.
// ready rises once all three are full. While ready is high, rden_i pops the three FIFOs together
// and data_out = {FIFO 2, FIFO 1, FIFO 0}; ready falls once they are empty.
module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 8,
    parameter NUM_FIFO   = 3
) (
    input  wire                    clk,
    input  wire                    resetn,
    output wire                    ready,
    input  wire                    wren_i,
    input  wire                    rden_i,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output wire [3*DATA_WIDTH-1:0] data_out
);

    wire full_0, full_1, full_2;
    wire empty_0, empty_1, empty_2;

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

    // writes are taken only while ready is low, into the first FIFO with room
    wire write  = wren_i & ~ready_r;
    wire wren_0 = write & ~full_0;
    wire wren_1 = write &  full_0 & ~full_1;
    wire wren_2 = write &  full_0 &  full_1 & ~full_2;

    // the rows are read together, while ready is high and until they run empty
    wire rden_all = rden_i & ready_r & ~empty_0;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo_0 (
        .clk(clk),
        .rst_n(resetn),
        .wren_i(wren_0),
        .rden_i(rden_all),
        .wdata_i(data_in),
        .rdata_o(data_out[DATA_WIDTH-1:0]),
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
        .rdata_o(data_out[2*DATA_WIDTH-1:DATA_WIDTH]),
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
        .rdata_o(data_out[3*DATA_WIDTH-1:2*DATA_WIDTH]),
        .full_o(full_2),
        .empty_o(empty_2)
    );

endmodule
