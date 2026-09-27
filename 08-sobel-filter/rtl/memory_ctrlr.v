`timescale 1ns / 1ps

// Sobel filter controller: reads the padded 102x102 input image from BRAM1, streams it through the
// line buffer and Sobel window, and writes the 100x100 edge image into BRAM2.
//
// READ: 307 cycles load the next three rows (306 pixels) into the line buffer; the BRAM1 address
//       then steps back two rows, so consecutive windows overlap by two rows.
// CONV: the line buffer is read; each valid window produces one output pixel. After 101 valid
//       cycles the controller returns to READ, and after output pixel 9999 it moves to DONE.
//
// sobel_window registers its gradient sums, so edge_out arrives one cycle after the window is
// valid. The BRAM2 write enable and address are delayed by the same cycle; the state machine and
// counters still run on the undelayed valid, which paces reads from the line buffer.
module memory_ctrlr #(
    parameter BRAM1_BW   = 8,
    parameter BRAM1_AMAX = 10404,
    parameter BRAM1_ADR  = $clog2(BRAM1_AMAX),
    parameter BRAM2_BW   = 8,
    parameter BRAM2_AMAX = 10000,
    parameter BRAM2_ADR  = $clog2(BRAM2_AMAX)
) (
    input  wire                 clk,
    input  wire                 resetn,
    input  wire                 start,
    output wire                 done,

    output wire                 s1_en,
    output wire                 s1_we,
    output wire [BRAM1_ADR-1:0] s1_addr,
    input  wire [BRAM1_BW-1:0]  s1_dout,

    output wire                 s2_en,
    output wire                 s2_we,
    output wire [BRAM2_ADR-1:0] s2_addr,
    output wire [BRAM2_BW-1:0]  s2_din
);

    localparam IDLE = 2'b00;
    localparam READ = 2'b01;
    localparam CONV = 2'b10;
    localparam DONE = 2'b11;

    reg  [1:0]           state;
    reg  [1:0]           next_state;
    reg  [8:0]           read_count;
    reg  [6:0]           conv_count;
    reg  [BRAM1_ADR-1:0] s1_addr_r;
    reg  [BRAM1_ADR-1:0] s2_addr_r;
    reg                  s2_we_q;
    reg  [BRAM2_ADR-1:0] s2_addr_q;
    reg                  fifo_wren;
    reg                  fifo_rden;

    wire                 ready;
    wire                 valid;
    wire [BRAM2_BW-1:0]  edge_out;
    wire [BRAM1_BW-1:0]  row0;
    wire [BRAM1_BW-1:0]  row1;
    wire [BRAM1_BW-1:0]  row2;

    wire conv_write = (state == CONV) && valid;

    assign s1_en   = (state == READ);
    assign s1_we   = 1'b0;
    assign s1_addr = s1_addr_r;

    assign s2_en   = s2_we_q;
    assign s2_we   = s2_we_q;
    assign s2_addr = s2_addr_q;
    assign s2_din  = edge_out;

    // the last pixel is written in the first DONE cycle; report done once it has landed
    assign done = (state == DONE) && !s2_we_q;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s2_we_q   <= 1'b0;
            s2_addr_q <= 0;
        end else begin
            s2_we_q   <= conv_write;
            s2_addr_q <= s2_addr_r;
        end
    end

    // line buffer write and read enables follow the state one cycle later
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            fifo_wren <= 1'b0;
            fifo_rden <= 1'b0;
        end else begin
            fifo_wren <= (state == READ);
            fifo_rden <= (state == CONV);
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:    next_state = start ? READ : IDLE;
            READ:    next_state = (read_count == 9'd306) ? CONV : READ;
            CONV: begin
                if (s2_addr_r == 14'd9999)
                    next_state = DONE;
                else if (conv_count == 7'd100)
                    next_state = READ;
                else
                    next_state = CONV;
            end
            DONE:    next_state = !resetn ? IDLE : DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            read_count <= 9'd0;
        else if (state == READ)
            read_count <= (read_count == 9'd306) ? 9'd0 : read_count + 9'd1;
        else
            read_count <= 9'd0;
    end

    // BRAM1 address: advance while reading, then step back two rows for the next window rows
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            s1_addr_r <= 14'd0;
        else if (state == READ) begin
            if (read_count == 9'd306)
                s1_addr_r <= s1_addr_r - 204;
            else
                s1_addr_r <= s1_addr_r + 14'd1;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            conv_count <= 7'd0;
        else if (conv_write)
            conv_count <= (conv_count == 7'd100) ? 7'd0 : conv_count + 7'd1;
        else
            conv_count <= 7'd0;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            s2_addr_r <= 14'd0;
        else if (conv_write)
            s2_addr_r <= s2_addr_r + 1;
    end

    line_buffer #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(102),
        .NUM_FIFO(3)
    ) u_line_buffer (
        .clk(clk),
        .resetn(resetn),
        .ready(ready),
        .wren_i(fifo_wren),
        .rden_i(fifo_rden),
        .data_in(s1_dout),
        .data_out0(row0),
        .data_out1(row1),
        .data_out2(row2)
    );

    sobel_window #(
        .DATA_WIDTH(8)
    ) u_sobel_window (
        .clk(clk),
        .resetn(resetn),
        .data_in0(row0),
        .data_in1(row1),
        .data_in2(row2),
        .ready(ready),
        .edge_out(edge_out),
        .valid(valid),
        .result_valid()
    );

endmodule
