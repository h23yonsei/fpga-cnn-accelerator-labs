`timescale 1ns / 1ps

// Running-sum controller and its block RAM. While the controller runs it owns the RAM's read port;
// once done is high, port B is handed to the ext_* signals so the result can be read back.
module top_memory_wrapper #(
    parameter INIT_FILE = "initialize_memory.hex"    // initial RAM contents, $readmemh format
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    output wire        done,

    input  wire        ext_enb,
    input  wire [7:0]  ext_addrb,
    output wire [15:0] ext_doutb
);

    wire        ena;
    wire        wea;
    wire [7:0]  addra;
    wire [15:0] dina;

    wire        ctrl_enb;
    wire [7:0]  ctrl_addrb;

    wire        enb   = done ? ext_enb   : ctrl_enb;
    wire [7:0]  addrb = done ? ext_addrb : ctrl_addrb;
    wire [15:0] doutb;

    assign ext_doutb = doutb;

    memory_ctrlr u_memory_ctrlr (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),
        .enb(ctrl_enb),
        .addrb(ctrl_addrb),
        .doutb(doutb)
    );

    bram #(.INIT_FILE(INIT_FILE)) u_bram (
        .clka(clk),
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),
        .clkb(clk),
        .enb(enb),
        .addrb(addrb),
        .doutb(doutb)
    );

endmodule
