`timescale 1ns / 1ps

// Controller and datapath of the CNN accelerator. One run classifies the three 28x28 images held
// in the input memory, stacked into one 28x84 frame:
//
//   CONV1               conv1_layer reads the frame and writes eight feature maps to the
//                       sram_conv1_result memories.
//   CONV2_00..CONV2_15  conv2_layer computes one output channel per state from the Conv1 maps and
//                       writes it to that channel's sram_conv2_result memory, one byte per image.
//                       Meanwhile the previous channel's memory is read back, two rows at a time,
//                       into the three maxpool_fc_argmax classifiers (one per image).
//   MAXFC               the last channel is read back and the classifiers finish.
//   DONE                the three predictions are held until the next start.
//
// Each CONV state reads the next 72 convolution weights; the FC weight memories are read in step
// with the pooled pixels. conv2_layer has a latency of CONV2_LAT cycles, so everything that touches
// the Conv2 result memories (write address, enables, the MaxPool read address, read mux and valid)
// runs from a copy of the state delayed CONV2_LAT - 1 cycles, and a channel is always completely
// written before it is read.
module cnn_fsm #(
    parameter SRAM_INPUT_BW         = 8,
    parameter SRAM_INPUT_AMAX       = 2352,
    parameter SRAM_INPUT_ADR        = $clog2(SRAM_INPUT_AMAX),
    parameter SRAM_CONV_WEIGHT_BW   = 8,
    parameter SRAM_CONV_WEIGHT_AMAX = 1224,
    parameter SRAM_CONV_WEIGHT_ADR  = $clog2(SRAM_CONV_WEIGHT_AMAX),
    parameter SRAM_FCL_WEIGHT_BW    = 8,
    parameter SRAM_FCL_WEIGHT_AMAX  = 2304,
    parameter SRAM_FCL_WEIGHT_ADR   = $clog2(SRAM_FCL_WEIGHT_AMAX)
)(
    input  wire                                  clk,
    input  wire                                  resetn,
    input  wire                                  start,
    output wire                                  done,

    // predicted digit for each of the three images
    output wire [3:0]                            result_0,
    output wire [3:0]                            result_1,
    output wire [3:0]                            result_2,

    // input image memory
    output wire                                  input_en,
    output wire                                  input_we,
    output reg  [SRAM_INPUT_ADR-1:0]             input_addr,
    input  wire signed [SRAM_INPUT_BW-1:0]       input_dout,

    // convolution weight memory
    output wire                                  conv_en,
    output wire                                  conv_we,
    output reg  [SRAM_CONV_WEIGHT_ADR-1:0]       conv_addr,
    input  wire signed [SRAM_CONV_WEIGHT_BW-1:0] conv_dout,

    // FC weight memories, one per class
    output wire                                  fcl_en_0,
    output wire                                  fcl_en_1,
    output wire                                  fcl_en_2,
    output wire                                  fcl_en_3,
    output wire                                  fcl_en_4,
    output wire                                  fcl_en_5,
    output wire                                  fcl_en_6,
    output wire                                  fcl_en_7,
    output wire                                  fcl_en_8,
    output wire                                  fcl_en_9,

    output wire                                  fcl_we_0,
    output wire                                  fcl_we_1,
    output wire                                  fcl_we_2,
    output wire                                  fcl_we_3,
    output wire                                  fcl_we_4,
    output wire                                  fcl_we_5,
    output wire                                  fcl_we_6,
    output wire                                  fcl_we_7,
    output wire                                  fcl_we_8,
    output wire                                  fcl_we_9,

    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_0,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_1,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_2,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_3,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_4,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_5,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_6,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_7,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_8,
    output wire [SRAM_FCL_WEIGHT_ADR-1:0]        fcl_addr_9,

    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_0,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_1,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_2,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_3,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_4,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_5,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_6,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_7,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_8,
    input  wire signed [SRAM_FCL_WEIGHT_BW-1:0]  fcl_dout_9
);

    localparam IDLE     = 5'd0;
    localparam CONV1    = 5'd1;
    localparam CONV2_00 = 5'd2;     // CONV2_00 + k: Conv2 output channel k
    localparam CONV2_15 = 5'd17;
    localparam MAXFC    = 5'd18;
    localparam DONE     = 5'd19;

    // latency of conv2_layer; must match conv2_layer.v
    localparam CONV2_LAT = 11;

    // the accelerator only reads its memories
    assign input_we = 1'b0;
    assign conv_we  = 1'b0;
    assign fcl_we_0 = 1'b0;
    assign fcl_we_1 = 1'b0;
    assign fcl_we_2 = 1'b0;
    assign fcl_we_3 = 1'b0;
    assign fcl_we_4 = 1'b0;
    assign fcl_we_5 = 1'b0;
    assign fcl_we_6 = 1'b0;
    assign fcl_we_7 = 1'b0;
    assign fcl_we_8 = 1'b0;
    assign fcl_we_9 = 1'b0;

    // ---------------------------------------------------------------------------------------------
    // State machine
    // ---------------------------------------------------------------------------------------------

    reg  [4:0] state;
    reg  [4:0] next_state;
    wire       conv1_done;
    wire       conv2_done;
    wire       maxfc_done;
    wire       in_conv2 = (state >= CONV2_00) && (state <= CONV2_15);

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:    next_state = start      ? CONV1    : IDLE;
            CONV1:   next_state = conv1_done ? CONV2_00 : CONV1;
            MAXFC:   next_state = maxfc_done ? DONE     : MAXFC;
            DONE:    next_state = start      ? CONV1    : DONE;
            default: begin
                if (in_conv2)
                    next_state = conv2_done ? state + 5'd1 : state;
                else
                    next_state = IDLE;
            end
        endcase
    end

    assign done = (state == DONE);

    // ---------------------------------------------------------------------------------------------
    // Delayed state for the Conv2 result memories and the MaxPool reads
    // ---------------------------------------------------------------------------------------------

    reg [4:0]         state_dl [1:CONV2_LAT];     // state_dl[n]: state delayed n cycles
    reg [CONV2_LAT:1] conv2_done_dl;

    integer n;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            for (n = 1; n <= CONV2_LAT; n = n + 1)
                state_dl[n] <= IDLE;
            conv2_done_dl <= 0;
        end else begin
            state_dl[1] <= state;
            for (n = 2; n <= CONV2_LAT; n = n + 1)
                state_dl[n] <= state_dl[n-1];
            conv2_done_dl <= {conv2_done_dl[CONV2_LAT-1:1], conv2_done};
        end
    end

    wire [4:0] pool_state      = state_dl[CONV2_LAT-1];
    wire       conv2_done_pool = conv2_done_dl[CONV2_LAT-1];

    // One-hot decodes of pool_state (bit k: CONV2_00 + k, bit 16: MAXFC), registered a cycle early
    // so they carry the same timing, and replicated for their fan-out. pool_hot_d is the same
    // decode one cycle later.
    (* max_fanout = 16 *) reg [16:0] pool_hot;
    (* max_fanout = 16 *) reg [16:1] pool_hot_d;

    integer h;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pool_hot   <= 17'd0;
            pool_hot_d <= 16'd0;
        end else begin
            for (h = 0; h <= 16; h = h + 1)
                pool_hot[h] <= (state_dl[CONV2_LAT-2] == CONV2_00 + h);
            for (h = 1; h <= 16; h = h + 1)
                pool_hot_d[h] <= (pool_state == CONV2_00 + h);
        end
    end

    // ---------------------------------------------------------------------------------------------
    // Weights
    // ---------------------------------------------------------------------------------------------

    // Convolution weight read data and address, registered. The weight data fans out to the 16
    // filter_window blocks (over 140 weight registers); registering it removes that load from the
    // memory output. conv2_layer delays its weight-load enable by the same cycle.
    (* max_fanout = 32 *) reg signed [SRAM_CONV_WEIGHT_BW-1:0] conv_dout_q;
    reg [SRAM_CONV_WEIGHT_ADR-1:0] conv_addr_q;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            conv_dout_q <= 0;
            conv_addr_q <= 0;
        end else begin
            conv_dout_q <= conv_dout;
            conv_addr_q <= conv_addr;
        end
    end

    // 72 weights per CONV state: CONV1 (state 1) reads 0-71, CONV2_00 + k (state k + 2) reads the
    // next 72, so each state reads up to address 72 * state
    wire        conv_state = (state >= CONV1) && (state <= CONV2_15);
    wire [10:0] conv_limit = state * 11'd72;

    assign conv_en = conv_state && (conv_addr < conv_limit);

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            conv_addr <= 0;
        else if (conv_en)
            conv_addr <= conv_addr + 1;
        else if (maxfc_done)
            conv_addr <= 0;
    end

    // ---------------------------------------------------------------------------------------------
    // Conv1
    // ---------------------------------------------------------------------------------------------

    assign input_en = (state == CONV1);

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            input_addr <= 0;
        else if (input_en)
            input_addr <= input_addr + 1;
        else
            input_addr <= 0;
    end

    wire [7:0] conv1_data [0:7];
    wire       conv1_valid;

    conv1_layer #(
        .OUT_WIDTH(26),
        .OUT_HEIGHT(78),
        .OUT_DEPTH(26 * 78)
    ) u_conv1 (
        .clk(clk),
        .resetn(resetn),
        .valid_in(state_dl[1] == CONV1),
        .pixel_in(input_dout),
        .weight_in(conv_dout_q),
        .weight_addr(conv_addr_q[6:0]),
        .valid_out(conv1_valid),
        .out_data0(conv1_data[0]),
        .out_data1(conv1_data[1]),
        .out_data2(conv1_data[2]),
        .out_data3(conv1_data[3]),
        .out_data4(conv1_data[4]),
        .out_data5(conv1_data[5]),
        .out_data6(conv1_data[6]),
        .out_data7(conv1_data[7]),
        .done(conv1_done)
    );

    // Conv1 writes its results in order; each Conv2 channel then reads them back from address 0
    reg  [10:0] conv1_addr;
    wire [7:0]  conv2_in [0:7];

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            conv1_addr <= 11'd0;
        end else if (state == CONV1) begin
            if (conv1_valid)
                conv1_addr <= conv1_addr + 11'd1;
            else if (conv1_done)
                conv1_addr <= 11'd0;
        end else if (in_conv2) begin
            if (conv2_done)
                conv1_addr <= 11'd0;
            else
                conv1_addr <= conv1_addr + 11'd1;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_conv1_result
            sram_conv1_result u_sram_conv1_result (
                .clka(clk),
                .ena(conv1_valid || in_conv2),
                .wea(conv1_valid),
                .addra(conv1_addr),
                .dina(conv1_data[i]),
                .douta(conv2_in[i])
            );
        end
    endgenerate

    // ---------------------------------------------------------------------------------------------
    // Conv2
    // ---------------------------------------------------------------------------------------------

    // in_conv2 delayed one cycle, registered so it can be replicated for its fan-out
    (* max_fanout = 64 *) reg conv2_valid_in;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            conv2_valid_in <= 1'b0;
        else
            conv2_valid_in <= in_conv2;
    end

    wire [2:0]  conv2_we;
    wire [23:0] conv2_data;
    wire        conv2_valid;

    conv2_layer #(
        .OUT_WIDTH(24),
        .OUT_HEIGHT(72),
        .OUT_DEPTH(24 * 72)
    ) u_conv2 (
        .clk(clk),
        .resetn(resetn),
        .valid_in(conv2_valid_in),
        .valid_in_next(in_conv2),
        .in_data0(conv2_in[0]),
        .in_data1(conv2_in[1]),
        .in_data2(conv2_in[2]),
        .in_data3(conv2_in[3]),
        .in_data4(conv2_in[4]),
        .in_data5(conv2_in[5]),
        .in_data6(conv2_in[6]),
        .in_data7(conv2_in[7]),
        .weight_in(conv_dout_q),
        .result_we(conv2_we),
        .result_data(conv2_data),
        .valid_out(conv2_valid),
        .done(conv2_done)
    );

    // Write address of the Conv2 result memories (24 x 24 words per channel). It advances on the
    // delayed state, so the last writes of CONV2_15 still get their increment.
    wire       conv2_write = |pool_hot[15:0];
    reg  [9:0] conv2_addr;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            conv2_addr <= 10'd0;
        end else if (conv2_write) begin
            if (conv2_valid)
                conv2_addr <= (conv2_addr < 10'd575) ? conv2_addr + 10'd1 : 10'd0;
            else if (conv2_done)
                conv2_addr <= 10'd0;
        end else if (start) begin
            conv2_addr <= 10'd0;
        end
    end

    // Read addresses: pool_row steps over the even rows, and port A reads row pool_row while port B
    // reads the row below it
    reg  [4:0] pool_row;
    reg  [4:0] pool_col;
    wire [9:0] pool_addr_a = pool_row * 24 + pool_col;
    wire [9:0] pool_addr_b = (pool_row + 1) * 24 + pool_col;
    wire       pool_read   = |pool_hot[16:1];
    wire       pool_read_d = |pool_hot_d[16:1];

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pool_row <= 5'd0;
            pool_col <= 5'd0;
        end else if (start || conv2_done_pool) begin
            pool_row <= 5'd0;
            pool_col <= 5'd0;
        end else if (pool_read) begin
            if (pool_col < 5'd23) begin
                pool_col <= pool_col + 5'd1;
            end else begin
                pool_col <= 5'd0;
                pool_row <= pool_row + 5'd2;
            end
        end
    end

    // Channel k's memory is written while pool_hot[k] and read while pool_hot[k+1]
    wire [23:0] conv2_douta [0:15];
    wire [23:0] conv2_doutb [0:15];

    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_conv2_result
            sram_conv2_result u_sram_conv2_result (
                .clka(clk),
                .ena(pool_hot[i] && conv2_valid || pool_hot[i+1]),
                .wea(pool_hot[i] ? conv2_we : 3'b000),
                .addra(pool_hot[i] ? conv2_addr : pool_hot[i+1] ? pool_addr_a : 10'd0),
                .dina(conv2_data),
                .douta(conv2_douta[i]),
                .clkb(clk),
                .enb(pool_hot[i+1]),
                .web(3'b000),
                .addrb(pool_addr_b),
                .dinb(24'd0),
                .doutb(conv2_doutb[i])
            );
        end
    endgenerate

    // ---------------------------------------------------------------------------------------------
    // MaxPool, FC and ArgMax
    // ---------------------------------------------------------------------------------------------

    // Read mux over the 16 result memories, a priority chain ending in 0
    wire [23:0] top_chain    [0:16];
    wire [23:0] bottom_chain [0:16];

    assign top_chain[16]    = 24'd0;
    assign bottom_chain[16] = 24'd0;

    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_read_mux
            assign top_chain[i]    = pool_hot[i+1] ? conv2_douta[i] : top_chain[i+1];
            assign bottom_chain[i] = pool_hot[i+1] ? conv2_doutb[i] : bottom_chain[i+1];
        end
    endgenerate

    // Each channel yields 288 reads (12 row pairs x 24 columns); pool_count restarts whenever
    // pool_state changes
    reg  [4:0] pool_state_prev;
    reg  [8:0] pool_count;
    wire       pool_valid = pool_read_d && (pool_count < 288);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pool_state_prev <= IDLE;
            pool_count      <= 9'd0;
        end else if (pool_state != pool_state_prev) begin
            pool_state_prev <= pool_state;
            pool_count      <= 9'd0;
        end else if (pool_state > CONV2_00 && pool_state <= MAXFC) begin
            if (pool_count < 9'd288)
                pool_count <= pool_count + 9'd1;
        end
    end

    // MaxPool inputs: the read mux and its valid, registered together
    reg [23:0] pool_top_q, pool_bottom_q;
    reg        pool_valid_q;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            pool_top_q    <= 24'd0;
            pool_bottom_q <= 24'd0;
            pool_valid_q  <= 1'b0;
        end else begin
            pool_top_q    <= top_chain[0];
            pool_bottom_q <= bottom_chain[0];
            pool_valid_q  <= pool_valid;
        end
    end

    wire [2:0] pooled_valid;
    wire [2:0] classify_done;
    wire [3:0] prediction [0:2];

    // byte i of each result word belongs to image i
    generate
        for (i = 0; i < 3; i = i + 1) begin : gen_classifier
            maxpool_fc_argmax #(
                .DATA_WIDTH(8),
                .PIXEL_NUM(2304)
            ) u_maxpool_fc_argmax (
                .clk(clk),
                .resetn(resetn),
                .start(start),
                .px_row0(pool_top_q[8*i +: 8]),
                .px_row1(pool_bottom_q[8*i +: 8]),
                .valid_in(pool_valid_q),
                .maxpool_valid_out(pooled_valid[i]),
                .weight_0(fcl_dout_0),
                .weight_1(fcl_dout_1),
                .weight_2(fcl_dout_2),
                .weight_3(fcl_dout_3),
                .weight_4(fcl_dout_4),
                .weight_5(fcl_dout_5),
                .weight_6(fcl_dout_6),
                .weight_7(fcl_dout_7),
                .weight_8(fcl_dout_8),
                .weight_9(fcl_dout_9),
                .argmax_out(prediction[i]),
                .valid_out(classify_done[i])
            );
        end
    endgenerate

    assign result_0   = prediction[0];
    assign result_1   = prediction[1];
    assign result_2   = prediction[2];
    assign maxfc_done = &classify_done;

    // FC weight memories: read one address per pooled pixel
    wire                          fcl_en = &pooled_valid;
    reg [SRAM_FCL_WEIGHT_ADR-1:0] fcl_addr;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            fcl_addr <= 0;
        else if (start)
            fcl_addr <= 0;
        else if (fcl_en)
            fcl_addr <= fcl_addr + 1;
        else if (fcl_addr == SRAM_FCL_WEIGHT_AMAX - 1)
            fcl_addr <= 0;
    end

    assign fcl_en_0   = fcl_en;
    assign fcl_en_1   = fcl_en;
    assign fcl_en_2   = fcl_en;
    assign fcl_en_3   = fcl_en;
    assign fcl_en_4   = fcl_en;
    assign fcl_en_5   = fcl_en;
    assign fcl_en_6   = fcl_en;
    assign fcl_en_7   = fcl_en;
    assign fcl_en_8   = fcl_en;
    assign fcl_en_9   = fcl_en;

    assign fcl_addr_0 = fcl_addr;
    assign fcl_addr_1 = fcl_addr;
    assign fcl_addr_2 = fcl_addr;
    assign fcl_addr_3 = fcl_addr;
    assign fcl_addr_4 = fcl_addr;
    assign fcl_addr_5 = fcl_addr;
    assign fcl_addr_6 = fcl_addr;
    assign fcl_addr_7 = fcl_addr;
    assign fcl_addr_8 = fcl_addr;
    assign fcl_addr_9 = fcl_addr;

endmodule
