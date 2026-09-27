`timescale 1ns / 1ps

// Circular FIFO on a simple dual-port block RAM, sized for one 102-pixel image row.
//
// Each pointer is one bit wider than the address: the low bits index the memory and the top bit
// records a wrap. The FIFO is empty when both pointers are equal and full when the addresses match
// but the wrap bits differ. Reads come out of the block RAM with one clock cycle of latency.
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 102
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wren_i,     // write enable
    input  wire                  rden_i,     // read enable
    input  wire [DATA_WIDTH-1:0] wdata_i,
    output wire [DATA_WIDTH-1:0] rdata_o,
    output wire                  full_o,
    output wire                  empty_o
);

    localparam FIFO_DEPTH_LG2 = $clog2(FIFO_DEPTH);    // address width
    localparam MEM_ADDR_WIDTH = 7;                     // address width of the 128-entry memory

    reg [FIFO_DEPTH_LG2:0] wrptr;
    reg [FIFO_DEPTH_LG2:0] rdptr;

    assign empty_o = (wrptr == rdptr);
    assign full_o  = (wrptr[FIFO_DEPTH_LG2-1:0] == rdptr[FIFO_DEPTH_LG2-1:0]) &&
                     (wrptr[FIFO_DEPTH_LG2] != rdptr[FIFO_DEPTH_LG2]);

    // write pointer: after the last address (FIFO_DEPTH - 1) it returns to address 0 and flips the
    // wrap bit
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wrptr <= {(FIFO_DEPTH_LG2 + 1){1'b0}};
        else if (wren_i) begin
            if (wrptr[FIFO_DEPTH_LG2-1:0] == FIFO_DEPTH - 1)
                wrptr <= {~wrptr[FIFO_DEPTH_LG2], {FIFO_DEPTH_LG2{1'b0}}};
            else
                wrptr <= wrptr + 'd1;
        end
    end

    // read pointer: same wrap rule
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdptr <= {(FIFO_DEPTH_LG2 + 1){1'b0}};
        else if (rden_i) begin
            if (rdptr[FIFO_DEPTH_LG2-1:0] == FIFO_DEPTH - 1)
                rdptr <= {~rdptr[FIFO_DEPTH_LG2], {FIFO_DEPTH_LG2{1'b0}}};
            else
                rdptr <= rdptr + 'd1;
        end
    end

    // Zero-extend the pointers to the memory's 7-bit address, so a shallower FIFO
    // (FIFO_DEPTH < 128) still drives every address bit instead of leaving the upper bits floating.
    wire [MEM_ADDR_WIDTH-1:0] wr_addr =
        {{(MEM_ADDR_WIDTH - FIFO_DEPTH_LG2){1'b0}}, wrptr[FIFO_DEPTH_LG2-1:0]};
    wire [MEM_ADDR_WIDTH-1:0] rd_addr =
        {{(MEM_ADDR_WIDTH - FIFO_DEPTH_LG2){1'b0}}, rdptr[FIFO_DEPTH_LG2-1:0]};

    fifo_mem u_mem (
        .clka(clk),
        .ena(wren_i),
        .wea(wren_i),
        .addra(wr_addr),
        .dina(wdata_i),
        .clkb(clk),
        .enb(rden_i),
        .addrb(rd_addr),
        .doutb(rdata_o)
    );

endmodule
