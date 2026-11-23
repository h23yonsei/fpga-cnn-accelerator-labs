`timescale 1ns / 1ps

// Weight register for one 3x3 kernel. While en is high one weight arrives per clock and is stored
// in row-major order, weight0 first; the position restarts whenever en drops.
module filter_window (
    input  wire              clk,
    input  wire              resetn,
    input  wire              en,
    input  wire [7:0]        data_in,

    output reg signed [7:0]  weight0,
    output reg signed [7:0]  weight1,
    output reg signed [7:0]  weight2,
    output reg signed [7:0]  weight3,
    output reg signed [7:0]  weight4,
    output reg signed [7:0]  weight5,
    output reg signed [7:0]  weight6,
    output reg signed [7:0]  weight7,
    output reg signed [7:0]  weight8
);

    reg [3:0] count;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            count   <= 4'd0;
            weight0 <= 8'd0;
            weight1 <= 8'd0;
            weight2 <= 8'd0;
            weight3 <= 8'd0;
            weight4 <= 8'd0;
            weight5 <= 8'd0;
            weight6 <= 8'd0;
            weight7 <= 8'd0;
            weight8 <= 8'd0;
        end else if (en) begin
            case (count)
                4'd0:    weight0 <= data_in;
                4'd1:    weight1 <= data_in;
                4'd2:    weight2 <= data_in;
                4'd3:    weight3 <= data_in;
                4'd4:    weight4 <= data_in;
                4'd5:    weight5 <= data_in;
                4'd6:    weight6 <= data_in;
                4'd7:    weight7 <= data_in;
                4'd8:    weight8 <= data_in;
                default: ;
            endcase
            if (count < 4'd10)
                count <= count + 4'd1;
        end else begin
            count <= 4'd0;
        end
    end

endmodule
