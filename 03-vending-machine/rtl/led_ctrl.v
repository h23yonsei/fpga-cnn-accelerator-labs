`timescale 1ns / 1ps

// Status LEDs. LED5 is lit while the machine is on (SW3 high). In filling mode LED2-LED4 show which
// item was filled last; in selling mode they show which items are out of stock; otherwise they are
// off. Everything is off while SW3 is low.
module led_ctrl (
    input  wire       sw3,
    input  wire [1:0] mode,
    input  wire [2:0] stock1,
    input  wire [2:0] stock2,
    input  wire [2:0] stock3,
    input  wire [1:0] last_filled_item,
    output reg        led2,
    output reg        led3,
    output reg        led4,
    output reg        led5
);

    localparam MODE_IDLE = 2'b00;
    localparam MODE_COIN = 2'b01;
    localparam MODE_SELL = 2'b10;
    localparam MODE_FILL = 2'b11;

    always @(*) begin
        if (!sw3) begin
            {led2, led3, led4, led5} = 4'b0000;
        end else begin
            led5 = 1'b1;
            case (mode)
                MODE_FILL: begin
                    led2 = (last_filled_item == 2'd1);
                    led3 = (last_filled_item == 2'd2);
                    led4 = (last_filled_item == 2'd3);
                end
                MODE_SELL: begin
                    led2 = (stock1 == 3'd0);
                    led3 = (stock2 == 3'd0);
                    led4 = (stock3 == 3'd0);
                end
                default: begin      // MODE_IDLE and MODE_COIN
                    {led2, led3, led4} = 3'b000;
                end
            endcase
        end
    end

endmodule
