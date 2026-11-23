`timescale 1ns / 1ps

// Top level of the Sobel filter IP: the controller with its line buffer and Sobel window, and the
// two image memories. Port B of each memory belongs to the controller; port A (s1_* and s2_*) is
// brought out so the Zynq PS can load BRAM1 and read BRAM2 through AXI BRAM controllers. The port
// names are part of the packaged IP's interface in the block design.
module top_memory_ctrlr (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    output wire        done,

    input  wire        s1_clka,
    input  wire        s1_ena,
    input  wire        s1_wea,
    input  wire [13:0] s1_addra,
    input  wire [7:0]  s1_dina,
    output wire [7:0]  s1_douta,

    input  wire        s2_clka,
    input  wire        s2_ena,
    input  wire        s2_wea,
    input  wire [13:0] s2_addra,
    input  wire [7:0]  s2_dina,
    output wire [7:0]  s2_douta
);

    wire        s1_en, s2_en;
    wire        s1_we, s2_we;
    wire [13:0] s1_addr;
    wire [13:0] s2_addr;
    wire [7:0]  s1_din, s1_dout;
    wire [7:0]  s2_din, s2_dout;

    // The controller only reads bram1 (its s1_we is tied low), so port B's write data is unused.
    assign s1_din = {8{1'b0}};

    memory_ctrlr #(
        .BRAM1_BW(8), .BRAM1_AMAX(10404),
        .BRAM2_BW(8), .BRAM2_AMAX(10000)
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

    bram1 u_bram1 (
        .clka(s1_clka),
        .ena(s1_ena),
        .wea(s1_wea),
        .addra(s1_addra),
        .dina(s1_dina),
        .douta(s1_douta),
        .clkb(clk),
        .enb(s1_en),
        .web(s1_we),
        .addrb(s1_addr),
        .dinb(s1_din),
        .doutb(s1_dout)
    );

    bram2 u_bram2 (
        .clka(s2_clka),
        .ena(s2_ena),
        .wea(s2_wea),
        .addra(s2_addra),
        .dina(s2_dina),
        .douta(s2_douta),
        .clkb(clk),
        .enb(s2_en),
        .web(s2_we),
        .addrb(s2_addr),
        .dinb(s2_din),
        .doutb(s2_dout)
    );

endmodule
