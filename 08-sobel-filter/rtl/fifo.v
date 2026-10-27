`timescale 1ns / 1ps

// Circular FIFO on a simple dual-port block RAM, used for one row of the line buffer.
//
// Each pointer is one bit wider than the address: the low bits index the memory and the top bit
// records a wrap. The FIFO is empty when both pointers are equal and full when the addresses match
// but the wrap bits differ. Writes are ignored while full and reads while empty; reads come out of
// the block RAM with one clock cycle of latency.
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 102
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wren_i,
    input  wire                  rden_i,
    input  wire [DATA_WIDTH-1:0] wdata_i,
    output wire [DATA_WIDTH-1:0] rdata_o,
    output wire                  full_o,
    output wire                  empty_o
);

    localparam FIFO_DEPTH_LG2 = $clog2(FIFO_DEPTH);    // address width

    reg [FIFO_DEPTH_LG2:0] wrptr;
    reg [FIFO_DEPTH_LG2:0] rdptr;

    wire [FIFO_DEPTH_LG2-1:0] wr_index = wrptr[FIFO_DEPTH_LG2-1:0];
    wire [FIFO_DEPTH_LG2-1:0] rd_index = rdptr[FIFO_DEPTH_LG2-1:0];
    wire                      wr_wrap  = wrptr[FIFO_DEPTH_LG2];
    wire                      rd_wrap  = rdptr[FIFO_DEPTH_LG2];

    assign empty_o = (wrptr == rdptr);
    assign full_o  = (wr_index == rd_index) && (wr_wrap != rd_wrap);

    wire write = wren_i && !full_o;
    wire read  = rden_i && !empty_o;

    // after the last address, a pointer returns to address 0 and flips its wrap bit
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wrptr <= 0;
        else if (write) begin
            if (wr_index == FIFO_DEPTH - 1)
                wrptr <= {~wr_wrap, {FIFO_DEPTH_LG2{1'b0}}};
            else
                wrptr <= wrptr + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdptr <= 0;
        else if (read) begin
            if (rd_index == FIFO_DEPTH - 1)
                rdptr <= {~rd_wrap, {FIFO_DEPTH_LG2{1'b0}}};
            else
                rdptr <= rdptr + 1;
        end
    end

    fifo_mem u_mem (
        .clka(clk),
        .ena(write),
        .wea(write),
        .addra(wr_index),
        .dina(wdata_i),
        .clkb(clk),
        .enb(read),
        .addrb(rd_index),
        .doutb(rdata_o)
    );

endmodule
