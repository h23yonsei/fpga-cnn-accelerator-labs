`timescale 1ns / 1ps

// Behavioral model of the course's Block Memory Generator core used as FIFO storage: a 128 x 8-bit
// simple dual-port RAM, written on port A and read on port B with one clock cycle of read latency.
// The core's .xci file was not kept, so this model stands in for it. It follows Vivado's RAM
// inference template, so the same file simulates in xsim and synthesizes to block RAM.
module fifo_mem (
    input  wire       clka,
    input  wire       ena,
    input  wire [0:0] wea,
    input  wire [6:0] addra,
    input  wire [7:0] dina,
    input  wire       clkb,
    input  wire       enb,
    input  wire [6:0] addrb,
    output reg  [7:0] doutb
);

    reg [7:0] mem [0:127];

    initial doutb = 8'd0;

    always @(posedge clka) begin
        if (ena && wea[0])
            mem[addra] <= dina;
    end

    always @(posedge clkb) begin
        if (enb)
            doutb <= mem[addrb];
    end

endmodule
