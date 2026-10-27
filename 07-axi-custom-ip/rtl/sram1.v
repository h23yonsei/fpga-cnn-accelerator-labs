`timescale 1ns / 1ps

// Behavioral model of the Block Memory Generator core SRAM1: a 256 x 16-bit true dual-port RAM
// with byte-wide write enables and one clock cycle of write-first read latency on both ports. The
// core's .xci file was not kept, so this model stands in for it. It follows Vivado's RAM inference
// template, so the same file simulates in xsim and synthesizes to block RAM.
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

    initial begin
        douta = 16'd0;
        doutb = 16'd0;
    end

    // one always block per byte and port, as in the template
    genvar i;
    generate
        for (i = 0; i < 2; i = i + 1) begin : gen_byte
            always @(posedge clka) begin
                if (ena) begin
                    if (wea[i]) begin
                        mem[addra][8*i +: 8] <= dina[8*i +: 8];
                        douta[8*i +: 8]      <= dina[8*i +: 8];
                    end else begin
                        douta[8*i +: 8]      <= mem[addra][8*i +: 8];
                    end
                end
            end

            always @(posedge clkb) begin
                if (enb) begin
                    if (web[i]) begin
                        mem[addrb][8*i +: 8] <= dinb[8*i +: 8];
                        doutb[8*i +: 8]      <= dinb[8*i +: 8];
                    end else begin
                        doutb[8*i +: 8]      <= mem[addrb][8*i +: 8];
                    end
                end
            end
        end
    endgenerate

endmodule
