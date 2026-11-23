`timescale 1ns / 1ps

// Behavioral SRAM with a synchronous write and an asynchronous read. Writes and reads both carry a
// 1 ns delay; the output is unknown while the memory is not enabled.
module sram_model #(
    parameter BW   = 32,                // data width
    parameter AMAX = 512,               // number of words
    parameter ADR  = $clog2(AMAX)       // address width
) (
    input  wire           clk,
    input  wire           en,
    input  wire           we,
    input  wire [ADR-1:0] addr,
    input  wire [BW-1:0]  din,
    output wire [BW-1:0]  dout
);

    reg [BW-1:0] mem [0:AMAX-1];

    always @(posedge clk) begin
        if (en && we)
            mem[addr] <= #1 din;
    end

    assign #1 dout = en ? mem[addr] : {BW{1'bx}};

endmodule
