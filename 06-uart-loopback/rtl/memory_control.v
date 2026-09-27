`timescale 1ns / 1ps

// Receive / store / transmit controller of the UART loopback.
//
// IDLE: waits for rx_switch.
// RX:   stores each received byte at the next address until MEMORY_DEPTH bytes have arrived, then
//       lights the LED.
// TX:   once tx_switch is set (and the LED is lit), sends the stored bytes back in order. Each byte
//       is read one cycle after the transmitter pops the previous one, to allow for the block RAM's
//       read latency.
//
// The byte counters are one bit wider than the 14-bit address, so they can reach MEMORY_DEPTH when
// it is the full 16,384 bytes of the board design.
module memory_control #(
    parameter MEMORY_DEPTH = 100
) (
    input  wire        rst,
    input  wire        clk,
    input  wire        rx_switch,
    input  wire        tx_switch,
    output wire        led,

    // UART receiver
    input  wire [7:0]  uart_rx_data,
    input  wire        uart_rx_ready,

    // UART transmitter
    output reg  [7:0]  uart_tx_data,
    input  wire        uart_tx_pop,
    output wire        uart_tx_on,

    // block RAM
    output wire        memory_en,
    output wire        memory_write_en,
    output reg  [13:0] memory_addr,
    output wire [7:0]  memory_data_in,
    input  wire [7:0]  memory_data_out
);

    localparam IDLE = 2'b00;
    localparam RX   = 2'b01;
    localparam TX   = 2'b10;

    reg [1:0]  state;
    reg [14:0] rx_count;
    reg [14:0] tx_count;
    reg        read_pending;

    reg        led_r;
    reg        memory_en_r;
    reg        memory_write_en_r;
    reg [7:0]  memory_data_in_r;
    reg        uart_tx_on_r;

    assign led             = led_r;
    assign memory_en       = memory_en_r;
    assign memory_write_en = memory_write_en_r;
    assign memory_data_in  = memory_data_in_r;
    assign uart_tx_on      = uart_tx_on_r;

    wire rx_ready_pulse;
    wire tx_pop_pulse;

    posedge_detector u_rx_ready_edge (
        .clk(clk),
        .rst(rst),
        .sig(uart_rx_ready),
        .pulse(rx_ready_pulse)
    );

    posedge_detector u_tx_pop_edge (
        .clk(clk),
        .rst(rst),
        .sig(uart_tx_pop),
        .pulse(tx_pop_pulse)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state             <= IDLE;
            read_pending      <= 1'b0;
            led_r             <= 1'b0;
            rx_count          <= 15'd0;
            tx_count          <= 15'd0;
            memory_en_r       <= 1'b0;
            memory_write_en_r <= 1'b0;
            memory_addr       <= 14'd0;
            memory_data_in_r  <= 8'd0;
            uart_tx_data      <= 8'd0;
            uart_tx_on_r      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    memory_en_r       <= 1'b0;
                    memory_write_en_r <= 1'b0;
                    uart_tx_on_r      <= 1'b0;
                    if (rx_switch) begin
                        memory_en_r       <= 1'b1;
                        memory_write_en_r <= 1'b1;
                        rx_count          <= 15'd0;
                        state             <= RX;
                    end
                end

                RX: begin
                    if (rx_ready_pulse && (rx_count < MEMORY_DEPTH)) begin
                        memory_addr      <= rx_count[13:0];
                        rx_count         <= rx_count + 15'd1;
                        memory_data_in_r <= uart_rx_data;
                    end
                    if (rx_count == MEMORY_DEPTH)
                        led_r <= 1'b1;
                    if (tx_switch && led_r) begin
                        tx_count          <= 15'd0;
                        memory_write_en_r <= 1'b0;
                        state             <= TX;
                    end
                end

                TX: begin
                    if (tx_count < MEMORY_DEPTH + 1) begin
                        uart_tx_on_r <= 1'b1;
                        memory_addr  <= tx_count[13:0];
                        if (tx_pop_pulse && !read_pending) begin
                            read_pending <= 1'b1;
                        end else if (read_pending) begin
                            uart_tx_data <= memory_data_out;
                            tx_count     <= tx_count + 15'd1;
                            read_pending <= 1'b0;
                        end
                    end else begin
                        uart_tx_on_r <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
