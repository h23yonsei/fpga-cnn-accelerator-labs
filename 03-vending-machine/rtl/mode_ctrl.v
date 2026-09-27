`timescale 1ns / 1ps

// Operating mode of the vending machine, registered at 50 Hz. SW3 low forces IDLE; with SW3 high,
// SW1 high selects coin inserting, SW2 high with SW1 low selects item filling, and both low select
// selling.
module mode_ctrl (
    input  wire       clk_50hz,
    input  wire       sw1,
    input  wire       sw2,
    input  wire       sw3,
    output wire [1:0] mode
);

    localparam MODE_IDLE = 2'b00;
    localparam MODE_COIN = 2'b01;
    localparam MODE_SELL = 2'b10;
    localparam MODE_FILL = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    always @(posedge clk_50hz) begin
        if (!sw3)
            state <= MODE_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        if (!sw3) begin
            next_state = MODE_IDLE;
        end else begin
            case ({sw1, sw2})
                2'b00:        next_state = MODE_SELL;
                2'b01:        next_state = MODE_FILL;
                2'b10, 2'b11: next_state = MODE_COIN;
                default:      next_state = MODE_IDLE;
            endcase
        end
    end

    assign mode = state;

endmodule
