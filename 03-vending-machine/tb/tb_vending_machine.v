`timescale 1ns / 1ps

// Testbench for the vending machine.
//
// The 50 Hz clock is driven directly (the clock divider is the one checked in
// 02-counter-and-fsm/counter), so seconds of button presses simulate quickly. The sequence and
// expected values follow the assignment spec: items cost 3, 5 and 7; coins are worth 1, 5 and 10;
// stock stops at 5 and balance at 50; SW1/SW2 select coin inserting, item filling or selling; SW3
// turns the machine on and off. LED2-LED4 show the most recently filled item in filling mode and
// out-of-stock items in selling mode; LED5 is on while the machine is on.
module tb_vending_machine;

    reg  clk = 1'b0;
    reg  sw1 = 1'b0, sw2 = 1'b0, sw3 = 1'b0;
    reg  btn1 = 1'b0, btn2 = 1'b0, btn3 = 1'b0;
    wire LED2, LED3, LED4, LED5;
    wire aa, ab, ac, ad, ae, af, ag, cat;

    integer errors = 0;

    vending_machine dut (
        .clk(clk),
        .btn1(btn1), .btn2(btn2), .btn3(btn3),
        .sw1(sw1), .sw2(sw2), .sw3(sw3),
        .LED2(LED2), .LED3(LED3), .LED4(LED4), .LED5(LED5),
        .aa(aa), .ab(ab), .ac(ac), .ad(ad), .ae(ae), .af(af), .ag(ag),
        .cat(cat)
    );

    reg clk_50hz_tb = 1'b0;
    always #10_000_000 clk_50hz_tb = ~clk_50hz_tb;
    initial force dut.clk_50hz = clk_50hz_tb;

    task press(input integer index);
        begin
            #100;
            case (index)
                1: btn1 = 1'b1;
                2: btn2 = 1'b1;
                3: btn3 = 1'b1;
            endcase
            #20_000_000;
            {btn1, btn2, btn3} = 3'b000;
            #50_000_000;
        end
    endtask

    task expect_state(input [7:0] exp_balance, input [2:0] exp_stock1, input [2:0] exp_stock2,
                      input [2:0] exp_stock3, input [3:0] exp_leds, input [8*44-1:0] what);
        begin
            if (dut.balance !== exp_balance || dut.stock1 !== exp_stock1 ||
                dut.stock2 !== exp_stock2 || dut.stock3 !== exp_stock3 ||
                {LED2, LED3, LED4, LED5} !== exp_leds) begin
                errors = errors + 1;
                $display("MISMATCH %0s:", what);
                $display("    got      balance=%0d stock=%0d/%0d/%0d LED2-5=%b",
                         dut.balance, dut.stock1, dut.stock2, dut.stock3, {LED2, LED3, LED4, LED5});
                $display("    expected balance=%0d stock=%0d/%0d/%0d LED2-5=%b",
                         exp_balance, exp_stock1, exp_stock2, exp_stock3, exp_leds);
            end else begin
                $display("ok  %0s: balance=%0d stock=%0d/%0d/%0d LED2-5=%b",
                         what, exp_balance, exp_stock1, exp_stock2, exp_stock3, exp_leds);
            end
        end
    endtask

    initial begin
        sw3 = 1'b1;
        #40_000_000;

        // item filling (SW2 high): six presses per item, stock stops at 5, LED4 marks item 3
        sw1 = 1'b0; sw2 = 1'b1;
        repeat (6) press(1);
        repeat (6) press(2);
        repeat (6) press(3);
        expect_state(0, 5, 5, 5, 4'b0011, "fill each item 6 times, stock stops at 5");

        // coin inserting (SW1 high): 3 x 10 + 3 x 5 + 3 x 1 = 48
        sw1 = 1'b1; sw2 = 1'b0;
        repeat (3) press(3);
        repeat (3) press(2);
        repeat (3) press(1);
        expect_state(48, 5, 5, 5, 4'b0001, "insert coins up to 48");
        press(3);
        press(2);
        expect_state(48, 5, 5, 5, 4'b0001, "coins of 10 and 5 above 50 are refused");
        repeat (2) press(1);
        expect_state(50, 5, 5, 5, 4'b0001, "two coins of 1 reach 50");
        press(1);
        expect_state(50, 5, 5, 5, 4'b0001, "a coin of 1 above 50 is refused");

        // selling (SW1 = SW2 = 0)
        sw1 = 1'b0; sw2 = 1'b0;
        repeat (6) press(1);
        expect_state(35, 0, 5, 5, 4'b1001, "sell item 1 until out of stock (5 x 3)");
        repeat (6) press(3);
        expect_state(0, 0, 5, 0, 4'b1011, "sell item 3 until balance runs out (5 x 7)");

        sw1 = 1'b1; sw2 = 1'b0;
        repeat (5) press(3);
        expect_state(50, 0, 5, 0, 4'b0001, "insert 5 x 10");

        sw1 = 1'b0; sw2 = 1'b0;
        repeat (6) press(2);
        expect_state(25, 0, 0, 0, 4'b1111, "sell item 2 until out of stock (5 x 5)");

        // SW3 off clears everything and turns the LEDs off; on again leaves the machine empty
        sw3 = 1'b0;
        #40_000_000;
        expect_state(0, 0, 0, 0, 4'b0000, "SW3 off clears balance, stock and LEDs");
        sw3 = 1'b1;
        #40_000_000;
        expect_state(0, 0, 0, 0, 4'b1111, "SW3 on again, selling with no stock");

        if (errors == 0)
            $display("PASS: vending machine behaves as specified");
        else
            $display("FAIL: %0d vending machine checks failed", errors);
        $finish;
    end

endmodule
