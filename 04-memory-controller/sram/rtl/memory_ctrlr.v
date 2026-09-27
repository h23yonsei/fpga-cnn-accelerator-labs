`timescale 1ns / 1ps

// Packs a 256 x 16-bit SRAM (SRAM1) into a 192 x 32-bit SRAM (SRAM2) in two phases.
//
// Phase 1: words 0-127 of SRAM1 are packed in pairs from the top of SRAM2 down:
//          SRAM2[191 - i] = {SRAM1[2i], SRAM1[2i + 1]}.
// Phase 2: words 128-255 are placed from address 0 up, even words in the low half
//          ({16'h0, SRAM1[c]}) and odd words in the high half ({SRAM1[c], 16'h0}).
// done rises when the last word has been written.
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

    localparam IDLE     = 3'd0;
    localparam P1_READ1 = 3'd1;     // phase 1: address the first word of a pair
    localparam P1_READ2 = 3'd2;     // phase 1: keep it, address the second word
    localparam P1_WRITE = 3'd3;     // phase 1: write the packed pair
    localparam P2_READ  = 3'd4;     // phase 2: address one word
    localparam P2_WRITE = 3'd5;     // phase 2: write it into the low or high half
    localparam FINISH   = 3'd6;

    reg [2:0]           state   = IDLE;
    reg [SRAM1_ADR-1:0] s1_cursor = 0;
    reg [SRAM2_ADR-1:0] s2_cursor = 191;
    reg [SRAM1_BW-1:0]  first_word;
    reg                 done_r;

    reg                 s1_en_r, s1_we_r;
    reg                 s2_en_r, s2_we_r;
    reg [SRAM1_ADR-1:0] s1_addr_r;
    reg [SRAM2_ADR-1:0] s2_addr_r;
    reg [SRAM2_BW-1:0]  s2_din_r;

    assign done    = done_r;
    assign s1_en   = s1_en_r;
    assign s1_we   = s1_we_r;
    assign s1_addr = s1_addr_r;
    assign s2_en   = s2_en_r;
    assign s2_we   = s2_we_r;
    assign s2_addr = s2_addr_r;
    assign s2_din  = s2_din_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state     <= IDLE;
            s1_cursor <= 0;
            s2_cursor <= 191;
            done_r    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done_r <= 1'b0;
                    if (start) begin
                        s1_cursor <= 0;
                        s2_cursor <= 191;
                        state     <= P1_READ1;
                    end
                end

                P1_READ1: begin
                    s1_en_r   <= 1'b1;
                    s1_we_r   <= 1'b0;
                    s1_addr_r <= s1_cursor;
                    s2_addr_r <= s2_cursor;
                    state     <= P1_READ2;
                end

                P1_READ2: begin
                    first_word <= s1_dout;
                    s1_addr_r  <= s1_cursor + 1;
                    state      <= P1_WRITE;
                end

                P1_WRITE: begin
                    s2_en_r   <= 1'b1;
                    s2_we_r   <= 1'b1;
                    s2_din_r  <= {first_word, s1_dout};
                    s1_cursor <= s1_cursor + 8'd2;
                    s2_cursor <= s2_cursor - 8'd1;
                    // after the pair starting at word 126, phase 2 fills SRAM2 from address 0
                    if (s1_cursor >= 126) begin
                        state     <= P2_READ;
                        s2_cursor <= 0;
                    end else begin
                        state <= P1_READ1;
                    end
                end

                P2_READ: begin
                    s1_en_r   <= 1'b1;
                    s1_we_r   <= 1'b0;
                    s1_addr_r <= s1_cursor;
                    state     <= P2_WRITE;
                end

                P2_WRITE: begin
                    s2_en_r   <= 1'b1;
                    s2_we_r   <= 1'b1;
                    s2_addr_r <= s2_cursor;
                    if (s1_cursor[0] == 1'b0)
                        s2_din_r <= {16'd0, s1_dout};
                    else
                        s2_din_r <= {s1_dout, 16'd0};
                    s1_cursor <= s1_cursor + 8'd1;
                    s2_cursor <= s2_cursor + 8'd1;
                    if (s1_cursor >= 255)
                        state <= FINISH;
                    else
                        state <= P2_READ;
                end

                FINISH: begin
                    done_r  <= 1'b1;
                    s1_en_r <= 1'b0;
                    s2_en_r <= 1'b0;
                    s2_we_r <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
