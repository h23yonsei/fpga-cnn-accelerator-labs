`timescale 1ns / 1ps

// Top level of the 0-9 up/down counter for the Arty S7-50.
//
// BTN0 counts up and stops at 9, BTN1 counts down and stops at 0, and SW0 low resets the count
// to 0. The count is shown on a seven-segment display wired to Pmod ports JC and JD. The segment
// pattern is registered on the same 50 Hz tick as the count, so the display follows one tick later.
module top_counter (
    input  wire       clk_100mhz,
    input  wire [1:0] btn,
    input  wire       sw,
    output reg  [3:0] jc,
    output reg  [3:0] jd
);

    wire      clk_50hz;
    wire      up_pulse;
    wire      down_pulse;
    reg [3:0] count = 4'd0;

    clock_divider u_clock_divider (
        .clk_100mhz(clk_100mhz),
        .clk_50hz(clk_50hz)
    );

    btn_debouncer u_btn_up (
        .clk(clk_50hz),
        .btn(btn[0]),
        .pulse(up_pulse)
    );

    btn_debouncer u_btn_down (
        .clk(clk_50hz),
        .btn(btn[1]),
        .pulse(down_pulse)
    );

    always @(posedge clk_50hz or negedge sw) begin
        if (!sw) begin
            count <= 4'd0;
            jc    <= 4'b1111;
            jd    <= 4'b0011;
        end else begin
            if (up_pulse && count < 4'd9)
                count <= count + 4'd1;
            else if (down_pulse && count > 4'd0)
                count <= count - 4'd1;

            // seven-segment pattern for the current count
            case (count)
                4'd0:    begin jc <= 4'b1111; jd <= 4'b0011; end
                4'd1:    begin jc <= 4'b0110; jd <= 4'b0000; end
                4'd2:    begin jc <= 4'b1011; jd <= 4'b0101; end
                4'd3:    begin jc <= 4'b1111; jd <= 4'b0100; end
                4'd4:    begin jc <= 4'b0110; jd <= 4'b0110; end
                4'd5:    begin jc <= 4'b1101; jd <= 4'b0110; end
                4'd6:    begin jc <= 4'b1101; jd <= 4'b0111; end
                4'd7:    begin jc <= 4'b0111; jd <= 4'b0000; end
                4'd8:    begin jc <= 4'b1111; jd <= 4'b0111; end
                4'd9:    begin jc <= 4'b0111; jd <= 4'b0110; end
                default: begin jc <= 4'b1111; jd <= 4'b0011; end
            endcase
        end
    end

endmodule
