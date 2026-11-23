`timescale 1ns / 1ps

// Behavioral model of the 74LS138 3-to-8 line decoder/demultiplexer.
//
// Port names follow the datasheet: G1 is an active-high enable, G2A and G2B are active-low enables,
// A (LSB), B and C select an output, and the eight outputs Y are active low. While the chip is
// enabled, only Y[{C, B, A}] is driven low; otherwise every output is high.
module decoder_74ls138 (
    input  wire       G1,
    input  wire       G2A,
    input  wire       G2B,
    input  wire       A,
    input  wire       B,
    input  wire       C,
    output reg  [7:0] Y
);

    always @(*) begin
        if (G1 && !G2A && !G2B) begin
            case ({C, B, A})
                3'd0:    Y = 8'b1111_1110;
                3'd1:    Y = 8'b1111_1101;
                3'd2:    Y = 8'b1111_1011;
                3'd3:    Y = 8'b1111_0111;
                3'd4:    Y = 8'b1110_1111;
                3'd5:    Y = 8'b1101_1111;
                3'd6:    Y = 8'b1011_1111;
                3'd7:    Y = 8'b0111_1111;
                default: Y = 8'b1111_1111;
            endcase
        end else begin
            Y = 8'b1111_1111;
        end
    end

endmodule
