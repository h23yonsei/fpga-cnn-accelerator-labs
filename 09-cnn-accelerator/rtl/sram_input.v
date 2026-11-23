`timescale 1ns / 1ps

// Behavioral model of the Block Memory Generator core sram_input: true dual port, 4096 x 8-bit,
// one-cycle write-first read on both ports, outputs power up at 0. The course project instantiated
// the core, but its .xci was not kept; this model reproduces the geometry and read latency the RTL
// expects. It follows Vivado's RAM inference templates, so it simulates in xsim and synthesizes to
// block RAM.
module sram_input (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [11:0] addra,
    input  wire [7:0]  dina,
    output reg  [7:0]  douta,
    input  wire        clkb,
    input  wire        enb,
    input  wire [0:0]  web,
    input  wire [11:0] addrb,
    input  wire [7:0]  dinb,
    output reg  [7:0]  doutb
);

    reg [7:0] mem [0:4095];

    initial begin
        douta = 0;
        doutb = 0;
    end

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

    always @(posedge clkb) begin
        if (enb) begin
            if (web[0]) begin
                mem[addrb] <= dinb;
                doutb      <= dinb;
            end else begin
                doutb <= mem[addrb];
            end
        end
    end

endmodule
