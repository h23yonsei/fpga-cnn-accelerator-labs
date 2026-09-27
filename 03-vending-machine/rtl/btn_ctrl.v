`timescale 1ns / 1ps

// Decodes a button press in the current mode into an action code. Exactly one button must be
// pressed; in coin mode BTN1-BTN3 insert coins of 1, 5 and 10, in selling mode they buy items 1-3,
// and in filling mode they restock items 1-3. The item number and coin value of the action are
// decoded alongside it. With no valid press the action is ACT_NONE.
module btn_ctrl (
    input  wire [1:0] mode,
    input  wire       btn1_pulse,
    input  wire       btn2_pulse,
    input  wire       btn3_pulse,
    output reg  [3:0] action,
    output reg  [1:0] item,
    output reg  [7:0] coin_value
);

    localparam MODE_IDLE = 2'b00;
    localparam MODE_COIN = 2'b01;
    localparam MODE_SELL = 2'b10;
    localparam MODE_FILL = 2'b11;

    // action codes, shared with action_ctrl
    localparam ACT_COIN_1  = 4'b0000;
    localparam ACT_SELL_1  = 4'b0001;
    localparam ACT_FILL_1  = 4'b0010;
    localparam ACT_COIN_5  = 4'b0011;
    localparam ACT_SELL_2  = 4'b0100;
    localparam ACT_FILL_2  = 4'b0101;
    localparam ACT_COIN_10 = 4'b0111;
    localparam ACT_SELL_3  = 4'b1000;
    localparam ACT_FILL_3  = 4'b1001;
    localparam ACT_NONE    = 4'b1111;

    always @(*) begin
        action     = ACT_NONE;
        item       = 2'd0;
        coin_value = 8'd0;

        if (mode != MODE_IDLE) begin
            if (btn1_pulse && !btn2_pulse && !btn3_pulse) begin
                case (mode)
                    MODE_COIN: action = ACT_COIN_1;
                    MODE_SELL: action = ACT_SELL_1;
                    MODE_FILL: action = ACT_FILL_1;
                    default:   action = ACT_NONE;
                endcase
            end else if (!btn1_pulse && btn2_pulse && !btn3_pulse) begin
                case (mode)
                    MODE_COIN: action = ACT_COIN_5;
                    MODE_SELL: action = ACT_SELL_2;
                    MODE_FILL: action = ACT_FILL_2;
                    default:   action = ACT_NONE;
                endcase
            end else if (!btn1_pulse && !btn2_pulse && btn3_pulse) begin
                case (mode)
                    MODE_COIN: action = ACT_COIN_10;
                    MODE_SELL: action = ACT_SELL_3;
                    MODE_FILL: action = ACT_FILL_3;
                    default:   action = ACT_NONE;
                endcase
            end
        end

        case (action)
            ACT_SELL_1, ACT_FILL_1: item = 2'd1;
            ACT_SELL_2, ACT_FILL_2: item = 2'd2;
            ACT_SELL_3, ACT_FILL_3: item = 2'd3;
            default:                item = 2'd0;
        endcase

        case (action)
            ACT_COIN_1:  coin_value = 8'd1;
            ACT_COIN_5:  coin_value = 8'd5;
            ACT_COIN_10: coin_value = 8'd10;
            default:     coin_value = 8'd0;
        endcase
    end

endmodule
