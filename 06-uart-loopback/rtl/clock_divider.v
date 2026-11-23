`timescale 1ns / 1ps

// Clock enable-style divider: clk_out is high for one input cycle out of every DIVIDE_RATE cycles
// (DIVIDE_RATE must be a power of two). With DIVIDE_RATE = 2 it turns the 100 MHz board clock into
// the 50 MHz clock the UART is designed for.
module clock_divider #(
    parameter DIVIDE_RATE = 2
) (
    input  wire clk_in,
    input  wire rst,
    output wire clk_out
);

    localparam COUNT_WIDTH = $clog2(DIVIDE_RATE);

    reg [COUNT_WIDTH-1:0] count;

    always @(posedge clk_in or posedge rst) begin
        if (rst)
            count <= {COUNT_WIDTH{1'b0}};
        else if (count == {COUNT_WIDTH{1'b1}})
            count <= {COUNT_WIDTH{1'b0}};
        else
            count <= count + 1'b1;
    end

    assign clk_out = (count == {COUNT_WIDTH{1'b1}});

endmodule
