`timescale 1ns / 1ps

// PC-side stand-in for the UART loopback test.
//
// The tester holds the test pattern (testpattern.txt, one byte per line in binary). While tx_switch
// is set it sends the bytes over its UART transmitter; while rx_switch is set it logs every byte
// received back from the design. Each byte sent is logged as "Tester transmit XX" and each byte
// received as "Tester received XX"; tools/run_sims.py compares the two sequences.
module tester_loopback #(
    parameter BAUD_RATE    = 115_200,
    parameter CLOCK_RATE   = 50_000_000,
    parameter MEMORY_DEPTH = 16384
) (
    input  wire clk,
    input  wire rst,
    input  wire rx_switch,
    input  wire tx_switch,
    input  wire uart_rx,
    output wire uart_tx
);

    wire        rst_sync;

    // ------------------------------------------------------------------------------------------
    // transmit side: send the test pattern
    reg  [7:0]  pattern [0:MEMORY_DEPTH-1];
    reg  [13:0] read_addr;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_pop;

    // The pattern file holds 4,096 bytes. It is read whole into an array of exactly that size, since
    // simulators disagree on a file longer than the array (Verilator stops), and the tester sends the
    // first MEMORY_DEPTH bytes of it; any address beyond the file sends i + 1.
    localparam PATTERN_BYTES = 4096;
    reg  [7:0]  pattern_file [0:PATTERN_BYTES-1];

    integer i;
    initial begin
        $readmemb("testpattern.txt", pattern_file);
        for (i = 0; i < MEMORY_DEPTH; i = i + 1)
            pattern[i] = (i < PATTERN_BYTES) ? pattern_file[i] : i + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            read_addr <= 14'd0;
        else if (tx_switch && uart_tx_pop && read_addr < MEMORY_DEPTH)
            read_addr <= read_addr + 14'd1;
    end

    assign uart_tx_data = pattern[read_addr];

    always @(read_addr)
        $display("Tester transmit %h to on-chip memory", uart_tx_data);

    // ------------------------------------------------------------------------------------------
    // receive side: log what comes back
    reg  [13:0] write_addr;
    wire        uart_rx_ready;
    wire        rx_ready_pulse;
    wire [7:0]  uart_rx_data;

    always @(posedge clk or posedge rst) begin
        if (rst)
            write_addr <= 14'd0;
        else if (!rx_switch)
            write_addr <= 14'd0;
        else if (rx_ready_pulse && uart_rx_data != 8'd0 && write_addr < MEMORY_DEPTH + 1)
            write_addr <= write_addr + 14'd1;
    end

    always @(posedge clk) begin
        if (rx_switch && rx_ready_pulse && uart_rx_data != 8'd0 &&
            write_addr < MEMORY_DEPTH + 1) begin
            $display("Tester received %h from on-chip memory", uart_rx_data);
            if (uart_rx_data == 8'd10)
                $finish;
        end
    end

    negedge_detector u_rx_ready_edge (
        .clk(clk),
        .rst(rst),
        .sig(uart_rx_ready),
        .pulse(rx_ready_pulse)
    );

    // ------------------------------------------------------------------------------------------
    // UART

    reset_bridge u_reset_bridge (
        .clk_dst(clk),
        .rst_in(rst),
        .rst_dst(rst_sync)
    );

    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) u_uart_rx (
        .clk_rx(clk),
        .rst_clk_rx(rst_sync),
        .rxd_i(uart_rx),
        .rx_data(uart_rx_data),
        .rx_data_rdy(uart_rx_ready)
    );

    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) u_uart_tx (
        .clk_tx(clk),
        .rst_clk_tx(rst_sync),
        .char_fifo_empty(1'b0),
        .char_fifo_dout(uart_tx_data),
        .char_fifo_rd_en(uart_tx_pop),
        .txd_tx(uart_tx)
    );

endmodule
