`timescale 1ns / 1ps

// Balance and stock of the vending machine, updated at 50 Hz from the decoded action.
//
// Items cost 3, 5 and 7. A coin is accepted only if the balance stays at or below 50. An item is
// sold only if it is in stock and the balance covers its price, and restocked only while its stock
// is below 5. SW3 low clears the balance, the stock and the last filled item.
module action_ctrl (
    input  wire       clk_50hz,
    input  wire       sw3,
    input  wire [3:0] action,
    input  wire [1:0] item,
    input  wire [7:0] coin_value,
    output reg  [7:0] balance          = 8'd0,
    output reg  [2:0] stock1           = 3'd0,
    output reg  [2:0] stock2           = 3'd0,
    output reg  [2:0] stock3           = 3'd0,
    output reg  [1:0] last_filled_item = 2'd0
);

    // action codes, shared with btn_ctrl
    localparam ACT_COIN_1  = 4'b0000;
    localparam ACT_SELL_1  = 4'b0001;
    localparam ACT_FILL_1  = 4'b0010;
    localparam ACT_COIN_5  = 4'b0011;
    localparam ACT_SELL_2  = 4'b0100;
    localparam ACT_FILL_2  = 4'b0101;
    localparam ACT_COIN_10 = 4'b0111;
    localparam ACT_SELL_3  = 4'b1000;
    localparam ACT_FILL_3  = 4'b1001;

    localparam MAX_BALANCE = 50;
    localparam MAX_STOCK   = 5;

    reg [7:0] item_price;

    always @(*) begin
        case (item)
            2'd1:    item_price = 8'd3;
            2'd2:    item_price = 8'd5;
            2'd3:    item_price = 8'd7;
            default: item_price = 8'd0;
        endcase
    end

    always @(posedge clk_50hz) begin
        if (!sw3) begin
            balance          <= 8'd0;
            stock1           <= 3'd0;
            stock2           <= 3'd0;
            stock3           <= 3'd0;
            last_filled_item <= 2'd0;
        end else begin
            case (action)
                ACT_COIN_1, ACT_COIN_5, ACT_COIN_10: begin
                    if (balance + coin_value <= MAX_BALANCE)
                        balance <= balance + coin_value;
                end
                ACT_SELL_1: begin
                    if (balance >= item_price && stock1 > 0) begin
                        balance <= balance - item_price;
                        stock1  <= stock1 - 3'd1;
                    end
                end
                ACT_FILL_1: begin
                    if (stock1 < MAX_STOCK) begin
                        stock1           <= stock1 + 3'd1;
                        last_filled_item <= item;
                    end
                end
                ACT_SELL_2: begin
                    if (balance >= item_price && stock2 > 0) begin
                        balance <= balance - item_price;
                        stock2  <= stock2 - 3'd1;
                    end
                end
                ACT_FILL_2: begin
                    if (stock2 < MAX_STOCK) begin
                        stock2           <= stock2 + 3'd1;
                        last_filled_item <= item;
                    end
                end
                ACT_SELL_3: begin
                    if (balance >= item_price && stock3 > 0) begin
                        balance <= balance - item_price;
                        stock3  <= stock3 - 3'd1;
                    end
                end
                ACT_FILL_3: begin
                    if (stock3 < MAX_STOCK) begin
                        stock3           <= stock3 + 3'd1;
                        last_filled_item <= item;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule
