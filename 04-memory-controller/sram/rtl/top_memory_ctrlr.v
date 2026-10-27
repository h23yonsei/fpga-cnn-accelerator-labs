`timescale 1ns / 1ps

// Packing controller with its two SRAMs: u_sram1 (256 x 16-bit source) and u_sram2 (192 x 32-bit
// destination).
module top_memory_ctrlr (
    input  wire clk,
    input  wire resetn,
    input  wire start,
    output wire done
);

    localparam SRAM1_BW   = 16;
    localparam SRAM1_AMAX = 256;
    localparam SRAM1_ADR  = $clog2(SRAM1_AMAX);
    localparam SRAM2_BW   = 32;
    localparam SRAM2_AMAX = 192;
    localparam SRAM2_ADR  = $clog2(SRAM2_AMAX);

    wire                 s1_en, s2_en;
    wire                 s1_we, s2_we;
    wire [SRAM1_ADR-1:0] s1_addr;
    wire [SRAM2_ADR-1:0] s2_addr;
    wire [SRAM1_BW-1:0]  s1_din, s1_dout;
    wire [SRAM2_BW-1:0]  s2_din, s2_dout;

    // The controller only reads SRAM1, so its write data is unused.
    assign s1_din = {SRAM1_BW{1'b0}};

    memory_ctrlr #(
        .SRAM1_BW(SRAM1_BW), .SRAM1_AMAX(SRAM1_AMAX),
        .SRAM2_BW(SRAM2_BW), .SRAM2_AMAX(SRAM2_AMAX)
    ) u_memory_ctrlr (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .s1_en(s1_en),
        .s1_we(s1_we),
        .s1_addr(s1_addr),
        .s1_dout(s1_dout),
        .s2_en(s2_en),
        .s2_we(s2_we),
        .s2_addr(s2_addr),
        .s2_din(s2_din)
    );

    sram_model #(.BW(SRAM1_BW), .AMAX(SRAM1_AMAX)) u_sram1 (
        .clk(clk), .en(s1_en), .we(s1_we), .addr(s1_addr), .din(s1_din), .dout(s1_dout)
    );

    sram_model #(.BW(SRAM2_BW), .AMAX(SRAM2_AMAX)) u_sram2 (
        .clk(clk), .en(s2_en), .we(s2_we), .addr(s2_addr), .din(s2_din), .dout(s2_dout)
    );

endmodule
