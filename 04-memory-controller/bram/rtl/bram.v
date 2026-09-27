`timescale 1ns / 1ps

// Behavioral model of the course's Block Memory Generator core: a 256 x 16-bit simple dual-port
// RAM, written on port A and read on port B with the primitive output register enabled (two clock
// cycles of read latency), initialized from INIT_FILE. The core's .xci file was not kept, so this
// model stands in for it. It follows Vivado's RAM inference template, so the same file simulates
// in xsim and synthesizes to block RAM.
module bram #(
    parameter INIT_FILE = "initialize_memory.hex"
) (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [7:0]  addra,
    input  wire [15:0] dina,
    input  wire        clkb,
    input  wire        enb,
    input  wire [7:0]  addrb,
    output reg  [15:0] doutb
);

    reg [15:0] mem [0:255];
    reg [15:0] doutb_q;

    initial $readmemh(INIT_FILE, mem);

    initial begin
        doutb_q = 16'd0;
        doutb   = 16'd0;
    end

    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end

    always @(posedge clkb) begin
        if (enb)
            doutb_q <= mem[addrb];
        doutb <= doutb_q;
    end

endmodule
