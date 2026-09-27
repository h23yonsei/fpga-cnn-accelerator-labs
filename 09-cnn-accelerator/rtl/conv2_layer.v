`timescale 1ns / 1ps

// Second convolution layer, one output channel per run: cnn_fsm runs it 16 times. Each run loads
// the channel's 72 weights (eight 3x3 kernels, one per Conv1 feature map), slides the eight
// feature maps through eight window registers, and writes ReLU(sum of the eight dot products) into
// the byte of the result word that belongs to the current image (byte 0, 1 or 2).
//
// Latency: conv2_math takes 7 cycles, the eight-way adder tree 3 and the output register 1, so a
// window's result is written CONV2_LAT cycles after the window. Valid and write enable travel
// through delay lines of the same length; cnn_fsm uses the same CONV2_LAT.
module conv2_layer #(
    parameter OUT_WIDTH  = 24,
    parameter OUT_HEIGHT = 3 * OUT_WIDTH,
    parameter OUT_DEPTH  = OUT_WIDTH * OUT_HEIGHT
)(
    input  wire              clk,
    input  wire              resetn,
    input  wire              valid_in,
    input  wire              valid_in_next,     // valid_in one cycle ahead

    // Conv1 feature maps
    input  wire signed [7:0] in_data0,
    input  wire signed [7:0] in_data1,
    input  wire signed [7:0] in_data2,
    input  wire signed [7:0] in_data3,
    input  wire signed [7:0] in_data4,
    input  wire signed [7:0] in_data5,
    input  wire signed [7:0] in_data6,
    input  wire signed [7:0] in_data7,

    // registered weight read data, one cycle behind valid_in
    input  wire signed [7:0] weight_in,

    output wire [2:0]        result_we,
    output wire [23:0]       result_data,
    output wire              valid_out,
    output wire              done
);

    localparam CONV2_LAT = 11;
    localparam PLANE     = OUT_WIDTH * OUT_WIDTH;   // output pixels per image

    // ---------------------------------------------------------------------------------------------
    // Weights
    // ---------------------------------------------------------------------------------------------

    // The load enable is valid_in delayed one cycle to match the registered weight data, and the
    // restart (done) is delayed with it, so the counters restart in step with the data.
    reg       weight_valid;
    reg       done_d1, done_d2;
    reg [3:0] weight_count;     // position within the current kernel, 0-8
    reg [3:0] weight_ch;        // kernel being loaded, 0-7

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            weight_valid <= 1'b0;
            done_d1      <= 1'b0;
            done_d2      <= 1'b0;
        end else begin
            weight_valid <= valid_in;
            done_d1      <= done;
            done_d2      <= done_d1;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            weight_count <= 4'd0;
            weight_ch    <= 4'd0;
        end else if (weight_valid && !done_d2) begin
            if (weight_count == 4'd8) begin
                weight_count <= 4'd0;
                if (weight_ch != 4'd8)
                    weight_ch <= weight_ch + 4'd1;
            end else begin
                weight_count <= weight_count + 4'd1;
            end
        end else begin
            weight_count <= 4'd0;
            weight_ch    <= 4'd0;
        end
    end

    wire signed [7:0] weight [0:71];

    genvar c;
    generate
        for (c = 0; c < 8; c = c + 1) begin : gen_filter
            filter_window u_filter (
                .clk(clk),
                .resetn(resetn),
                .en((weight_ch == c) && weight_valid),
                .data_in(weight_in),
                .weight0(weight[9*c]),   .weight1(weight[9*c+1]), .weight2(weight[9*c+2]),
                .weight3(weight[9*c+3]), .weight4(weight[9*c+4]), .weight5(weight[9*c+5]),
                .weight6(weight[9*c+6]), .weight7(weight[9*c+7]), .weight8(weight[9*c+8])
            );
        end
    endgenerate

    // ---------------------------------------------------------------------------------------------
    // Windows and dot products
    // ---------------------------------------------------------------------------------------------

    // slide enable = valid_in && !done, registered one cycle early and replicated for its fan-out
    (* max_fanout = 64 *) reg slide_en;
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            slide_en <= 1'b0;
        else
            slide_en <= valid_in_next && !done;
    end

    wire signed [7:0] in_data [0:7];
    assign in_data[0] = in_data0;
    assign in_data[1] = in_data1;
    assign in_data[2] = in_data2;
    assign in_data[3] = in_data3;
    assign in_data[4] = in_data4;
    assign in_data[5] = in_data5;
    assign in_data[6] = in_data6;
    assign in_data[7] = in_data7;

    wire [7:0]         slide_full;
    wire [7:0]         slide_valid;
    wire signed [7:0]  tap0 [0:7], tap1 [0:7], tap2 [0:7];
    wire signed [7:0]  tap3 [0:7], tap4 [0:7], tap5 [0:7];
    wire signed [7:0]  tap6 [0:7], tap7 [0:7], tap8 [0:7];
    wire signed [19:0] dot  [0:7];

    generate
        for (c = 0; c < 8; c = c + 1) begin : gen_channel
            conv_slide_reg #(
                .INPUT_WIDTH(26),
                .OUTPUT_WIDTH(24),
                .REG_DEPTH(78)
            ) u_slide (
                .clk(clk),
                .resetn(resetn),
                .en(slide_en),
                .din(in_data[c]),
                .is_full(slide_full[c]),
                .is_valid(slide_valid[c]),
                .dout0(tap0[c]), .dout1(tap1[c]), .dout2(tap2[c]),
                .dout3(tap3[c]), .dout4(tap4[c]), .dout5(tap5[c]),
                .dout6(tap6[c]), .dout7(tap7[c]), .dout8(tap8[c])
            );

            conv2_math u_math (
                .clk(clk),
                .pixel0(tap0[c]), .pixel1(tap1[c]), .pixel2(tap2[c]),
                .pixel3(tap3[c]), .pixel4(tap4[c]), .pixel5(tap5[c]),
                .pixel6(tap6[c]), .pixel7(tap7[c]), .pixel8(tap8[c]),
                .weight0(weight[9*c]),   .weight1(weight[9*c+1]), .weight2(weight[9*c+2]),
                .weight3(weight[9*c+3]), .weight4(weight[9*c+4]), .weight5(weight[9*c+5]),
                .weight6(weight[9*c+6]), .weight7(weight[9*c+7]), .weight8(weight[9*c+8]),
                .result(dot[c])
            );
        end
    endgenerate

    // eight-way adder tree: 3 cycles, no reset on the datapath registers
    reg signed [20:0] sum1_0, sum1_1, sum1_2, sum1_3;
    reg signed [21:0] sum2_0, sum2_1;
    reg signed [23:0] sum3;

    always @(posedge clk) begin
        sum1_0 <= dot[0] + dot[1];
        sum1_1 <= dot[2] + dot[3];
        sum1_2 <= dot[4] + dot[5];
        sum1_3 <= dot[6] + dot[7];
        sum2_0 <= sum1_0 + sum1_1;
        sum2_1 <= sum1_2 + sum1_3;
        sum3   <= sum2_0 + sum2_1;
    end

    wire signed [7:0] relu_out;

    relu #(
        .IN_WIDTH(24)
    ) u_relu (
        .data_in(sum3),
        .data_out(relu_out)
    );

    // ---------------------------------------------------------------------------------------------
    // Control and output
    // ---------------------------------------------------------------------------------------------

    reg  [10:0] output_count;
    reg  [2:0]  we_s1;
    wire        window_valid = (&slide_valid) && (&slide_full) && (output_count < OUT_DEPTH);

    assign done = (output_count == OUT_DEPTH);

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            output_count <= 11'd0;
        else if (window_valid)
            output_count <= output_count + 11'd1;
        else if (done)
            output_count <= 11'd0;
    end

    // Byte select for the current image. It is registered one cycle behind window_valid, so it
    // compares output_count one pixel early.
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            we_s1 <= 3'b000;
        else if (!valid_in)
            we_s1 <= 3'b000;
        else if (output_count < PLANE - 1)
            we_s1 <= 3'b001;
        else if (output_count < 2 * PLANE - 1)
            we_s1 <= 3'b010;
        else if (output_count < 3 * PLANE - 1)
            we_s1 <= 3'b100;
        else
            we_s1 <= 3'b000;
    end

    reg [CONV2_LAT:1] valid_dl;             // valid_dl[n]: window_valid delayed n cycles
    reg [2:0]         we_dl [1:CONV2_LAT];  // we_dl[n]: we_s1 delayed n cycles

    integer k;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_dl <= 0;
            for (k = 1; k <= CONV2_LAT; k = k + 1)
                we_dl[k] <= 3'b000;
        end else begin
            valid_dl <= {valid_dl[CONV2_LAT-1:1], window_valid};
            we_dl[1] <= we_s1;
            for (k = 2; k <= CONV2_LAT; k = k + 1)
                we_dl[k] <= we_dl[k-1];
        end
    end

    // output register: the ReLU result placed in its image's byte, one cycle before the write
    wire              valid_pre = valid_dl[CONV2_LAT-1];
    wire [2:0]        we_pre    = we_dl[CONV2_LAT-1];
    wire signed [7:0] pixel_out = valid_pre ? relu_out : 8'd0;
    reg  [23:0]       result_data_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            result_data_r <= 24'd0;
        else
            result_data_r <= (we_pre == 3'b001) ? {16'd0, pixel_out} :
                             (we_pre == 3'b010) ? {8'd0, pixel_out, 8'd0} :
                             (we_pre == 3'b100) ? {pixel_out, 16'd0} :
                             24'd0;
    end

    assign result_data = result_data_r;
    assign result_we   = we_dl[CONV2_LAT];
    assign valid_out   = valid_dl[CONV2_LAT];

endmodule
