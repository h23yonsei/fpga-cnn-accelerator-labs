`timescale 1ns / 1ps

// Gate-level model of the 74LS138 3-to-8 line decoder/demultiplexer, built from AND and NOT
// gates. Ports and behavior match decoder_74ls138: active-low outputs, only Y[{C, B, A}] low
// while G1 = 1 and G2A = G2B = 0.
module decoder_74ls138_gates (
    input  wire       G1,
    input  wire       G2A,
    input  wire       G2B,
    input  wire       A,
    input  wire       B,
    input  wire       C,
    output wire [7:0] Y
);

    wire enable = G1 & ~G2A & ~G2B;

    // one NAND term per output
    assign Y[0] = ~(~A & ~B & ~C & enable);
    assign Y[1] = ~( A & ~B & ~C & enable);
    assign Y[2] = ~(~A &  B & ~C & enable);
    assign Y[3] = ~( A &  B & ~C & enable);
    assign Y[4] = ~(~A & ~B &  C & enable);
    assign Y[5] = ~( A & ~B &  C & enable);
    assign Y[6] = ~(~A &  B &  C & enable);
    assign Y[7] = ~( A &  B &  C & enable);

endmodule
