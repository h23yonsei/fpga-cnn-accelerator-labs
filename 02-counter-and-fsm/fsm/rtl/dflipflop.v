`timescale 1ns / 1ps

// Positive-edge D flip-flop.
module dflipflop (
    input  wire clk,
    input  wire d,
    output reg  q
);

    always @(posedge clk) begin
        q <= d;
    end

endmodule
