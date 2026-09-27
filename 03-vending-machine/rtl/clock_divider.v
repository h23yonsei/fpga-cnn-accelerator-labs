`timescale 1ns / 1ps

// Divides the 100 MHz board clock to 50 Hz: the output toggles every 1,000,000 input cycles.
// It starts high one cycle after power-up.
module clock_divider (
    input  wire clk_100mhz,
    output reg  clk_50hz
);

    localparam HALF_PERIOD = 1_000_000;     // 100 MHz cycles per 50 Hz half period

    reg [19:0] count       = 20'd0;
    reg        first_cycle = 1'b1;

    always @(posedge clk_100mhz) begin
        if (first_cycle) begin
            clk_50hz    <= 1'b1;
            first_cycle <= 1'b0;
        end else if (count == HALF_PERIOD - 1) begin
            clk_50hz <= ~clk_50hz;
            count    <= 20'd0;
        end else begin
            count <= count + 20'd1;
        end
    end

endmodule
