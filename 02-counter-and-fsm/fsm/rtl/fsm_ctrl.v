`timescale 1ns / 1ps

// IDLE / UP / DOWN / READY controller with a 0-15 counter.
//
// SW3 low holds IDLE and clears the count. With SW3 high the controller leaves IDLE for READY;
// SW0 high selects UP, SW1 high with SW0 low selects DOWN, and both low return to READY. The state
// is updated at 50 Hz; the count changes at 1 Hz by +1 in UP (stopping at 15) and -1 in DOWN
// (stopping at 0). LED[0] is lit in UP and LED[1] in DOWN.
module fsm_ctrl (
    input  wire       clk_1hz,
    input  wire       clk_50hz,
    input  wire       sw0,
    input  wire       sw1,
    input  wire       sw3,
    output reg  [3:0] count,
    output reg  [1:0] led
);

    localparam IDLE  = 2'b00;
    localparam UP    = 2'b01;
    localparam DOWN  = 2'b10;
    localparam READY = 2'b11;

    reg [1:0] state = IDLE;
    reg [1:0] next_state;

    always @(*) begin
        case (state)
            IDLE: begin
                if (!sw3)      next_state = IDLE;
                else           next_state = READY;
            end
            UP: begin
                if (!sw3)      next_state = IDLE;
                else if (!sw0) next_state = READY;
                else           next_state = UP;
            end
            DOWN: begin
                if (!sw3)              next_state = IDLE;
                else if (sw0)          next_state = UP;
                else if (!sw1 && !sw0) next_state = READY;
                else                   next_state = DOWN;
            end
            READY: begin
                if (!sw3)             next_state = IDLE;
                else if (sw0)         next_state = UP;
                else if (sw1 && !sw0) next_state = DOWN;
                else                  next_state = READY;
            end
            default: next_state = IDLE;
        endcase
    end

    // count, updated once per second
    always @(posedge clk_1hz or negedge sw3) begin
        if (!sw3) begin
            count <= 4'd0;
        end else begin
            case (state)
                UP:      if (count < 4'd15) count <= count + 4'd1;
                DOWN:    if (count > 4'd0)  count <= count - 4'd1;
                default: count <= count;
            endcase
        end
    end

    // state register and state LEDs
    always @(posedge clk_50hz or negedge sw3) begin
        if (!sw3) begin
            state <= IDLE;
            led   <= 2'b00;
        end else begin
            state <= next_state;
            case (state)
                UP:      led <= 2'b01;
                DOWN:    led <= 2'b10;
                default: led <= 2'b00;
            endcase
        end
    end

endmodule
