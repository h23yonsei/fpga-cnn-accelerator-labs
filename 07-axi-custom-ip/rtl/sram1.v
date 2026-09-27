`timescale 1ns / 1ps

// Behavioral model of the course's Block Memory Generator core SRAM1: a 256 x 16-bit true
// dual-port RAM with byte-wide write enables and one clock cycle of read-first read latency on both
// ports. The core's .xci file was not kept, so this model stands in for it. It follows Vivado's RAM
// inference template, so the same file simulates in xsim and synthesizes to block RAM.
module sram1 (
    input  wire        clka,
    input  wire        ena,
    input  wire [1:0]  wea,
    input  wire [7:0]  addra,
    input  wire [15:0] dina,
    output reg  [15:0] douta,
    input  wire        clkb,
    input  wire        enb,
    input  wire [1:0]  web,
    input  wire [7:0]  addrb,
    input  wire [15:0] dinb,
    output reg  [15:0] doutb
);

    reg [15:0] mem [0:255];
    integer ia, ib;

    initial begin
        douta = 16'd0;
        doutb = 16'd0;
    end

    always @(posedge clka) begin
        if (ena) begin
            for (ia = 0; ia < 2; ia = ia + 1)
                if (wea[ia])
                    mem[addra][8*ia +: 8] <= dina[8*ia +: 8];
            douta <= mem[addra];
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            for (ib = 0; ib < 2; ib = ib + 1)
                if (web[ib])
                    mem[addrb][8*ib +: 8] <= dinb[8*ib +: 8];
            doutb <= mem[addrb];
        end
    end

endmodule
