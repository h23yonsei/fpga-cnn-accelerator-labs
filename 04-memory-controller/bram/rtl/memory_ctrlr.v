`timescale 1ns / 1ps

// Replaces each entry of a 256 x 16-bit block RAM with the running sum of the entries up to it.
//
// For every address the controller presents the read address on port B, waits out the RAM's two
// cycles of read latency, captures the entry, adds it to the running sum, and writes the sum back
// to the same address on port A. done rises after entry 255 has been written and stays high.
//
// Port B's address is the cursor register itself, so it is on the port for the whole READ_ADDR
// state and the RAM samples it at the end of that state; its data is ready at the end of READ_DATA.
// Port B stays enabled from start until DONE. Each write is a one-cycle pulse on port A.
module memory_ctrlr (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    output wire        done,

    // port A: write
    output wire        ena,
    output wire        wea,
    output wire [7:0]  addra,
    output wire [15:0] dina,

    // port B: read
    output wire        enb,
    output wire [7:0]  addrb,
    input  wire [15:0] doutb
);

    localparam IDLE      = 3'd0;
    localparam READ_ADDR = 3'd1;    // the read address (cursor) is on port B
    localparam READ_WAIT = 3'd2;    // first cycle of read latency
    localparam READ_DATA = 3'd3;    // capture the entry
    localparam WRITE     = 3'd4;    // write the running sum back
    localparam DONE      = 3'd5;

    reg [2:0]  state;
    reg [7:0]  cursor;
    reg [15:0] sum;
    reg [15:0] read_data;

    reg        done_r;
    reg        ena_r;
    reg        wea_r;
    reg [7:0]  addra_r;
    reg [15:0] dina_r;
    reg        enb_r;

    assign done  = done_r;
    assign ena   = ena_r;
    assign wea   = wea_r;
    assign addra = addra_r;
    assign dina  = dina_r;
    assign enb   = enb_r;
    assign addrb = cursor;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= IDLE;
            cursor  <= 8'd0;
            sum     <= 16'd0;
            done_r  <= 1'b0;
            ena_r   <= 1'b0;
            wea_r   <= 1'b0;
            enb_r   <= 1'b0;
            addra_r <= 8'd0;
            dina_r  <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        cursor  <= 8'd0;
                        sum     <= 16'd0;
                        done_r  <= 1'b0;
                        ena_r   <= 1'b0;
                        wea_r   <= 1'b0;
                        enb_r   <= 1'b1;
                        addra_r <= 8'd0;
                        dina_r  <= 16'd0;
                        state   <= READ_ADDR;
                    end
                end
                READ_ADDR: begin
                    // the previous entry's write happens at this clock edge; end its pulse
                    ena_r <= 1'b0;
                    wea_r <= 1'b0;
                    state <= READ_WAIT;
                end
                READ_WAIT: begin
                    state <= READ_DATA;
                end
                READ_DATA: begin
                    read_data <= doutb;
                    state     <= WRITE;
                end
                WRITE: begin
                    ena_r   <= 1'b1;
                    wea_r   <= 1'b1;
                    addra_r <= cursor;
                    dina_r  <= sum + read_data;
                    sum     <= sum + read_data;
                    cursor  <= cursor + 8'd1;
                    // entry 255 is written at the next clock edge; the enables drop in DONE
                    if (cursor == 8'd255)
                        state <= DONE;
                    else
                        state <= READ_ADDR;
                end
                DONE: begin
                    ena_r  <= 1'b0;
                    wea_r  <= 1'b0;
                    enb_r  <= 1'b0;
                    done_r <= 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
