`timescale 1ns / 1ps

// Testbench for memory_control on its own, at the board design's depth of 16,384 bytes (one
// 128x128 image), which the UART-level testbench (tb_loopback) is too slow to reach. The UART is
// replaced by its handshake: each received byte is one rising edge of uart_rx_ready, each byte the
// transmitter takes is one rising edge of uart_tx_pop. The block RAM is modeled here with one
// cycle of read latency.
//
// Checks: the LED stays off until the last byte has arrived and then lights; every byte is stored
// at its own address; and in transmit, each pop hands the transmitter the next stored byte, in
// order, for all 16,384 bytes.
module tb_memory_control;

    localparam MEMORY_DEPTH = 128 * 128;

    reg clk = 1'b0;
    always #10 clk = ~clk;

    reg        rst           = 1'b1;
    reg        rx_switch     = 1'b0;
    reg        tx_switch     = 1'b0;
    reg  [7:0] uart_rx_data  = 8'd0;
    reg        uart_rx_ready = 1'b0;
    reg        uart_tx_pop   = 1'b0;

    wire        led;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_on;
    wire        memory_en;
    wire        memory_write_en;
    wire [13:0] memory_addr;
    wire [7:0]  memory_data_in;
    reg  [7:0]  memory_data_out = 8'd0;

    reg  [7:0]  memory [0:16383];

    always @(posedge clk) begin
        if (memory_en) begin
            if (memory_write_en)
                memory[memory_addr] <= memory_data_in;
            memory_data_out <= memory[memory_addr];
        end
    end

    memory_control #(
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) dut (
        .rst(rst),
        .clk(clk),
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
        .memory_addr(memory_addr),
        .memory_data_in(memory_data_in),
        .memory_data_out(memory_data_out)
    );

    // byte i of the test stream: never 0, and not a multiple of the address
    function [7:0] pattern(input integer i);
        pattern = (i * 7 + i / 256) % 255 + 1;
    endfunction

    integer i;
    integer errors = 0;

    task fail(input [8*64-1:0] what, input integer index, input [7:0] got, input [7:0] want);
        begin
            errors = errors + 1;
            if (errors <= 5)
                $display("MISMATCH %0s %0d: got %02h, expected %02h", what, index, got, want);
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        #1 rst = 1'b0;
        rx_switch = 1'b1;

        // receive
        for (i = 0; i < MEMORY_DEPTH; i = i + 1) begin
            @(posedge clk);
            #1 uart_rx_data = pattern(i); uart_rx_ready = 1'b1;
            repeat (2) @(posedge clk);
            #1 uart_rx_ready = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (led !== (i == MEMORY_DEPTH - 1)) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("MISMATCH LED after byte %0d: %b", i, led);
            end
        end

        for (i = 0; i < MEMORY_DEPTH; i = i + 1)
            if (memory[i] !== pattern(i))
                fail("memory address", i, memory[i], pattern(i));

        // transmit
        @(posedge clk);
        #1 tx_switch = 1'b1;
        for (i = 0; i < MEMORY_DEPTH; i = i + 1) begin
            repeat (2) @(posedge clk);
            #1 uart_tx_pop = 1'b1;
            @(posedge clk);
            #1 uart_tx_pop = 1'b0;
            repeat (3) @(posedge clk);
            #1;
            if (uart_tx_data !== pattern(i))
                fail("transmitted byte", i, uart_tx_data, pattern(i));
        end

        if (errors == 0)
            $display("PASS: memory_control stored and returned all %0d bytes; LED lit after the last",
                     MEMORY_DEPTH);
        else
            $display("FAIL: %0d mismatches", errors);
        $finish;
    end

endmodule
