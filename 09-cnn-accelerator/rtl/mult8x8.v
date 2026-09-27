`timescale 1ns / 1ps

// Signed 8 x 8 multiplier with input, product and output registers: three clock cycles from a/b
// to p. The registers have no reset, so Vivado can place all three inside one DSP48 block
// (AREG/BREG, MREG, PREG).
(* use_dsp = "yes" *)
module mult8x8 (
    input  wire               clk,
    input  wire signed [7:0]  a,
    input  wire signed [7:0]  b,
    output reg  signed [15:0] p
);

    reg signed [7:0]  a_r, b_r;
    reg signed [15:0] m_r;

    always @(posedge clk) begin
        a_r <= a;
        b_r <= b;
        m_r <= a_r * b_r;
        p   <= m_r;
    end

endmodule
