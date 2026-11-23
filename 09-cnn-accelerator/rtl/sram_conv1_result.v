`timescale 1ns / 1ps

// Behavioral model of the Block Memory Generator core sram_conv1_result: single port,
// 2048 x 8-bit, one-cycle write-first read, output powers up at 0. The course project instantiated
// the core, but its .xci was not kept; this model reproduces the geometry and read latency the RTL
// expects. It follows Vivado's RAM inference templates, so it simulates in xsim and synthesizes to
// block RAM.
module sram_conv1_result (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [10:0] addra,
    input  wire [7:0]  dina,
    output reg  [7:0]  douta
);

    reg [7:0] mem [0:2047];

    initial douta = 0;

    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) begin
                mem[addra] <= dina;
                douta      <= dina;
            end else begin
                douta <= mem[addra];
            end
        end
    end

endmodule
