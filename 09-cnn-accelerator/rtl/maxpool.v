`timescale 1ns / 1ps

// 2x2 max pooling over a two-row stream: each valid clock delivers one column, px_row0 above
// px_row1. Even columns are buffered; on each odd column the largest of the four pixels is output
// with valid_out high for one cycle.
module maxpool #(
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         resetn,
    input  wire signed [DATA_WIDTH-1:0] px_row0,
    input  wire signed [DATA_WIDTH-1:0] px_row1,
    input  wire                         valid_in,
    output reg  signed [DATA_WIDTH-1:0] px_out,
    output reg                          valid_out
);

    function signed [DATA_WIDTH-1:0] max4;
        input signed [DATA_WIDTH-1:0] a, b, c, d;
        reg   signed [DATA_WIDTH-1:0] ab_max, cd_max;
        begin
            ab_max = (a > b) ? a : b;
            cd_max = (c > d) ? c : d;
            max4   = (ab_max > cd_max) ? ab_max : cd_max;
        end
    endfunction

    reg signed [DATA_WIDTH-1:0] row0_buf, row1_buf;
    reg                         odd_col;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            row0_buf  <= 0;
            row1_buf  <= 0;
            odd_col   <= 1'b0;
            px_out    <= 0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            odd_col <= ~odd_col;
            if (!odd_col) begin
                row0_buf  <= px_row0;
                row1_buf  <= px_row1;
                valid_out <= 1'b0;
            end else begin
                px_out    <= max4(row0_buf, px_row0, row1_buf, px_row1);
                valid_out <= 1'b1;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
