`timescale 1ns / 1ps

// Testbench for the UART loopback. The tester (tester_loopback) plays the PC: it sends the first
// MEMORY_DEPTH bytes of the test pattern to the design while the design receives. Once the design's
// LED shows that every byte has arrived, the design is switched to transmit and the tester logs the
// bytes that come back. tools/run_sims.py checks that all of them return in order.
module tb_loopback;

    localparam MEMORY_DEPTH = 14'd100;

    reg clk_100mhz = 1'b0;
    always #5 clk_100mhz <= !clk_100mhz;

    reg  rst_pin;
    reg  rx_switch;
    reg  tx_switch;
    reg  rx_switch_tester;
    reg  tx_switch_tester;

    wire clk_50mhz;
    wire uart_rx;
    wire uart_tx;
    wire led;

    clock_divider #(
        .DIVIDE_RATE(2)
    ) u_clock_divider (
        .clk_in(clk_100mhz),
        .rst(rst_pin),
        .clk_out(clk_50mhz)
    );

    tester_loopback #(
        .BAUD_RATE(115_200),
        .CLOCK_RATE(50_000_000),
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) u_tester (
        .clk(clk_50mhz),
        .rst(rst_pin),
        .rx_switch(rx_switch_tester),
        .tx_switch(tx_switch_tester),
        .uart_rx(uart_tx),
        .uart_tx(uart_rx)
    );

    top_loopback #(
        .BAUD_RATE(115_200),
        .CLOCK_RATE(50_000_000),
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) dut (
        .clk(clk_100mhz),
        .rst(rst_pin),
        .uart_rx(uart_rx),
        .rx_switch(rx_switch),
        .tx_switch(tx_switch),
        .uart_tx(uart_tx),
        .led(led)
    );

    initial begin
        rst_pin          = 1'b0;
        rx_switch        = 1'b0;
        tx_switch        = 1'b0;
        rx_switch_tester = 1'b0;
        tx_switch_tester = 1'b0;
        #3   rst_pin          = 1'b1;
        #100 rst_pin          = 1'b0;
        #10  rx_switch        = 1'b1;     // design receives
        #10  tx_switch_tester = 1'b1;     // tester sends
        #200_000_000;
        $finish;
    end

    // once every byte has arrived, stop sending and loop the data back
    always @(posedge clk_50mhz) begin
        if (led == 1'b1) begin
            #300 rx_switch        =  1'b0;
                 tx_switch_tester <= 1'b0;
            #300 rx_switch_tester <= 1'b1;
            #300 tx_switch        <= 1'b1;
        end
    end

endmodule
