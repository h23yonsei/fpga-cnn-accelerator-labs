`timescale 1ns / 1ps

// Top level of the UART loopback for the Arty S7-50.
//
// The 100 MHz board clock is divided to the 50 MHz the UART is designed for. With rx_switch set,
// bytes received on uart_rx are stored in block RAM; once MEMORY_DEPTH bytes have arrived the LED
// lights, and with tx_switch set the stored bytes are sent back on uart_tx in the same order.
module top_loopback #(
    parameter BAUD_RATE    = 115_200,
    parameter CLOCK_RATE   = 50_000_000,
    parameter MEMORY_DEPTH = 128 * 128      // number of bytes in the transferred image
) (
    input  wire clk,
    input  wire rst,
    input  wire uart_rx,
    input  wire rx_switch,
    input  wire tx_switch,
    output wire uart_tx,
    output wire led
);

    wire        clk_50mhz;

    wire [7:0]  uart_rx_data;
    wire        uart_rx_ready;

    wire [7:0]  uart_tx_data;
    wire        uart_tx_pop;
    wire        uart_tx_on;

    wire        memory_en;
    wire        memory_write_en;
    wire [14:0] memory_addr;
    wire [7:0]  memory_data_in;
    wire [7:0]  memory_data_out;

    // memory_control addresses 16,384 bytes with 14 bits; the RAM's top address bit is tied low
    assign memory_addr[14] = 1'b0;

    clock_divider #(
        .DIVIDE_RATE(2)
    ) u_clock_divider (
        .clk_in(clk),
        .rst(rst),
        .clk_out(clk_50mhz)
    );

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) u_uart_rx (
        .clk_rx(clk_50mhz),
        .rst_clk_rx(rst),
        .rxd_i(uart_rx),
        .rx_data(uart_rx_data),
        .rx_data_rdy(uart_rx_ready)
    );

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) u_uart_tx (
        .clk_tx(clk_50mhz),
        .rst_clk_tx(rst),
        .char_fifo_empty(!uart_tx_on),
        .char_fifo_dout(uart_tx_data),
        .char_fifo_rd_en(uart_tx_pop),
        .txd_tx(uart_tx)
    );

    bram u_bram (
        .clka(clk_50mhz),
        .ena(memory_en),
        .wea(memory_write_en),
        .addra(memory_addr),
        .dina(memory_data_in),
        .douta(memory_data_out)
    );

    memory_control #(
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) u_memory_control (
        .rst(rst),
        .clk(clk_50mhz),
        .rx_switch(rx_switch),
        .tx_switch(tx_switch),
        .led(led),
        .uart_rx_data(uart_rx_data),
        .uart_rx_ready(uart_rx_ready),
        .uart_tx_data(uart_tx_data),
        .uart_tx_pop(uart_tx_pop),
        .uart_tx_on(uart_tx_on),
        .memory_en(memory_en),
        .memory_write_en(memory_write_en),
        .memory_addr(memory_addr[13:0]),
        .memory_data_in(memory_data_in),
        .memory_data_out(memory_data_out)
    );

endmodule
