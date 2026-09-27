`timescale 1ns / 1ps

// Top level of the three-item vending machine for the Arty S7-50.
//
// SW3 turns the machine on. SW1 high selects coin inserting, SW2 high (with SW1 low) item filling,
// and both low selling. Depending on the mode, BTN1-BTN3 insert a coin of 1, 5 or 10, restock an
// item, or buy it. The port names come from the course skeleton and the pin constraints: LED2-LED5
// are the status LEDs, aa-ag the display segments and cat the digit select.
module vending_machine (
    input  wire clk,
    input  wire btn1,
    input  wire btn2,
    input  wire btn3,
    input  wire sw1,
    input  wire sw2,
    input  wire sw3,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5,
    output wire aa,
    output wire ab,
    output wire ac,
    output wire ad,
    output wire ae,
    output wire af,
    output wire ag,
    output wire cat
);

    wire       clk_50hz;
    wire       btn1_pulse;
    wire       btn2_pulse;
    wire       btn3_pulse;
    wire [1:0] mode;
    wire [3:0] action;
    wire [1:0] item;
    wire [7:0] coin_value;
    wire [7:0] balance;
    wire [2:0] stock1;
    wire [2:0] stock2;
    wire [2:0] stock3;
    wire [1:0] last_filled_item;

    clock_divider u_clock_divider (
        .clk_100mhz(clk),
        .clk_50hz(clk_50hz)
    );

    btn_debouncer u_btn1_debouncer (.clk(clk_50hz), .btn(btn1), .pulse(btn1_pulse));
    btn_debouncer u_btn2_debouncer (.clk(clk_50hz), .btn(btn2), .pulse(btn2_pulse));
    btn_debouncer u_btn3_debouncer (.clk(clk_50hz), .btn(btn3), .pulse(btn3_pulse));

    mode_ctrl u_mode_ctrl (
        .clk_50hz(clk_50hz),
        .sw1(sw1),
        .sw2(sw2),
        .sw3(sw3),
        .mode(mode)
    );

    btn_ctrl u_btn_ctrl (
        .mode(mode),
        .btn1_pulse(btn1_pulse),
        .btn2_pulse(btn2_pulse),
        .btn3_pulse(btn3_pulse),
        .action(action),
        .item(item),
        .coin_value(coin_value)
    );

    action_ctrl u_action_ctrl (
        .clk_50hz(clk_50hz),
        .sw3(sw3),
        .action(action),
        .item(item),
        .coin_value(coin_value),
        .balance(balance),
        .stock1(stock1),
        .stock2(stock2),
        .stock3(stock3),
        .last_filled_item(last_filled_item)
    );

    led_ctrl u_led_ctrl (
        .sw3(sw3),
        .mode(mode),
        .stock1(stock1),
        .stock2(stock2),
        .stock3(stock3),
        .last_filled_item(last_filled_item),
        .led2(LED2),
        .led3(LED3),
        .led4(LED4),
        .led5(LED5)
    );

    ssd_ctrl u_ssd_ctrl (
        .clk_50hz(clk_50hz),
        .sw3(sw3),
        .mode(mode),
        .balance(balance),
        .stock1(stock1),
        .stock2(stock2),
        .stock3(stock3),
        .last_filled_item(last_filled_item),
        .seg_a(aa), .seg_b(ab), .seg_c(ac), .seg_d(ad),
        .seg_e(ae), .seg_f(af), .seg_g(ag),
        .digit_sel(cat)
    );

endmodule
