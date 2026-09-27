`timescale 1ns / 1ps

// Packs 256 16-bit words from SRAM1 into 192 32-bit words in SRAM2, reading and writing through
// the memories' port B (one clock cycle of read latency).
//
// RUN1 (128 cycles): SRAM1 addresses 0-127 are issued in order; every second cycle the word that
//                    has just arrived is written together with the word before it.
// RUN2 (128 cycles): SRAM1 addresses 128-255 are issued; each arriving word is written from SRAM2
//                    address 0 up, alternately into the low half ({16'h0, word}) and the high half
//                    ({word, 16'h0}).
// done stays high in DONE until reset.
//
// Each write takes the words as they arrive, one cycle after their address, so the data runs one
// word behind the addresses:
//     SRAM2[191 - i] = {SRAM1[2i - 1], SRAM1[2i]}     i = 0..63
//     SRAM2[j]       = {16'h0, SRAM1[127 + j]}        j = 0..127, j even
//     SRAM2[j]       = {SRAM1[127 + j], 16'h0}        j = 0..127, j odd
// where SRAM1[-1] is the port's previous output (0 after configuration) and SRAM1[255] is not
// copied. This is the layout of the course's answer file (vectors/answer_memory.hex).
module memory_ctrlr #(
    parameter SRAM1_BW   = 16,
    parameter SRAM1_AMAX = 256,
    parameter SRAM1_ADR  = $clog2(SRAM1_AMAX),
    parameter SRAM2_BW   = 32,
    parameter SRAM2_AMAX = 192,
    parameter SRAM2_ADR  = $clog2(SRAM2_AMAX)
) (
    input  wire                 clk,
    input  wire                 resetn,
    input  wire                 start,
    output wire                 done,

    output wire                 s1_en,
    output wire                 s1_we,
    output wire [SRAM1_ADR-1:0] s1_addr,
    input  wire [SRAM1_BW-1:0]  s1_dout,

    output wire                 s2_en,
    output wire                 s2_we,
    output wire [SRAM2_ADR-1:0] s2_addr,
    output wire [SRAM2_BW-1:0]  s2_din
);

    localparam IDLE = 2'b00;
    localparam RUN1 = 2'b01;
    localparam RUN2 = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0]          state;
    reg [1:0]          next_state;
    reg [6:0]          run1_count;
    reg [6:0]          run2_count;
    reg [SRAM1_BW-1:0] prev_word;       // SRAM1 word read on the previous RUN1 cycle
    reg                s2_write_pair;   // RUN1: a complete pair is ready to write
    reg [SRAM2_BW-1:0] s2_word;

    wire run1_last = (run1_count == 7'd127);
    wire run2_last = (run2_count == 7'd127);

    // SRAM1 (read only)
    assign s1_en   = (state == RUN1) || (state == RUN2);
    assign s1_we   = 1'b0;
    assign s1_addr = (state == RUN1) ? run1_count :
                     (state == RUN2) ? run2_count + 128 :
                                       {SRAM1_ADR{1'b0}};

    // SRAM2 (write only)
    assign s2_en   = (state == RUN1) ? s2_write_pair : (state == RUN2);
    assign s2_we   = (state == RUN1) ? s2_write_pair : (state == RUN2);
    assign s2_addr = (state == RUN1) ? 191 - (run1_count >> 1) :
                     (state == RUN2) ? run2_count :
                                       {SRAM2_ADR{1'b0}};
    assign s2_din  = s2_word;

    assign done = (state == DONE);

    always @(*) begin
        if (state == RUN1)
            s2_word = {prev_word, s1_dout};
        else if (state == RUN2)
            s2_word = run2_count[0] ? {s1_dout, 16'd0} : {16'd0, s1_dout};
        else
            s2_word = {SRAM2_BW{1'b0}};
    end

    always @(*) begin
        case (state)
            IDLE:    next_state = start     ? RUN1 : IDLE;
            RUN1:    next_state = run1_last ? RUN2 : RUN1;
            RUN2:    next_state = run2_last ? DONE : RUN2;
            DONE:    next_state = !resetn   ? IDLE : DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // a pair is complete on every second RUN1 cycle
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            s2_write_pair <= 1'b0;
        else if (state == RUN1)
            s2_write_pair <= run1_count[0] ? 1'b0 : s1_en;
        else
            s2_write_pair <= 1'b0;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            prev_word <= 16'd0;
        else if (state == RUN1)
            prev_word <= s1_dout;
        else
            prev_word <= 16'd0;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            run1_count <= 7'd0;
        else if (state == RUN1)
            run1_count <= run1_count + 7'd1;
        else
            run1_count <= 7'd0;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            run2_count <= 7'd0;
        else if (state == RUN2)
            run2_count <= run2_count + 7'd1;
        else
            run2_count <= 7'd0;
    end

endmodule
