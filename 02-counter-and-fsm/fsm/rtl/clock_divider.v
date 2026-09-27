`timescale 1ns / 1ps

// Divides the 100 MHz board clock to 50 Hz and 1 Hz. Each output toggles after half its period
// in input cycles and starts high one cycle after power-up.
module clock_divider (
    input  wire clk_100mhz,
    output reg  clk_50hz,
    output reg  clk_1hz
);

    localparam HALF_PERIOD_50HZ = 1_000_000;    // 100 MHz cycles per 50 Hz half period
    localparam HALF_PERIOD_1HZ  = 50_000_000;   // 100 MHz cycles per 1 Hz half period

    reg [19:0] count_50hz       = 20'd0;
    reg [25:0] count_1hz        = 26'd0;
    reg        first_cycle_50hz = 1'b1;
    reg        first_cycle_1hz  = 1'b1;

    always @(posedge clk_100mhz) begin
        if (first_cycle_50hz) begin
            clk_50hz         <= 1'b1;
            first_cycle_50hz <= 1'b0;
        end else if (count_50hz == HALF_PERIOD_50HZ - 1) begin
            clk_50hz   <= ~clk_50hz;
            count_50hz <= 20'd0;
        end else begin
            count_50hz <= count_50hz + 20'd1;
        end
    end

    always @(posedge clk_100mhz) begin
        if (first_cycle_1hz) begin
            clk_1hz         <= 1'b1;
            first_cycle_1hz <= 1'b0;
        end else if (count_1hz == HALF_PERIOD_1HZ - 1) begin
            clk_1hz   <= ~clk_1hz;
            count_1hz <= 26'd0;
        end else begin
            count_1hz <= count_1hz + 26'd1;
        end
    end

endmodule
