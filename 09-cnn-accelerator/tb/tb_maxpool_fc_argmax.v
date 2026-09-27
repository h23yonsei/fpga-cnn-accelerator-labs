`timescale 1ns / 1ps

// Testbench for MaxPool -> FC -> ArgMax on a small frame: two rows of 24 signed pixels are pooled
// 2x2 into 12 values, the FC layer accumulates them against one fixed weight per class, and ArgMax
// must return the class with the largest sum (lowest index on a tie). The expected class is
// computed here from the same pixels and weights. The full pipeline, with the course's trained
// weights, is checked by tb_cnn_fsm.
module tb_maxpool_fc_argmax;

    localparam DATA_WIDTH = 8;
    localparam PIXEL_NUM  = 12;

    reg                         clk;
    reg                         resetn;
    reg                         valid_in;
    reg  signed [DATA_WIDTH-1:0] px_row0;
    reg  signed [DATA_WIDTH-1:0] px_row1;
    reg  signed [DATA_WIDTH-1:0] weight_0, weight_1, weight_2, weight_3, weight_4;
    reg  signed [DATA_WIDTH-1:0] weight_5, weight_6, weight_7, weight_8, weight_9;
    wire [3:0]                   argmax_out;
    wire                         argmax_valid;

    maxpool_fc_argmax #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIXEL_NUM(PIXEL_NUM)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .start(1'b0),
        .px_row0(px_row0),
        .px_row1(px_row1),
        .valid_in(valid_in),
        .maxpool_valid_out(),
        .weight_0(weight_0),
        .weight_1(weight_1),
        .weight_2(weight_2),
        .weight_3(weight_3),
        .weight_4(weight_4),
        .weight_5(weight_5),
        .weight_6(weight_6),
        .weight_7(weight_7),
        .weight_8(weight_8),
        .weight_9(weight_9),
        .argmax_out(argmax_out),
        .valid_out(argmax_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // two 24-pixel rows (8-bit signed: 128 reads as -128) and one weight per class
    reg signed [DATA_WIDTH-1:0] row0 [0:23];
    reg signed [DATA_WIDTH-1:0] row1 [0:23];
    reg signed [DATA_WIDTH-1:0] w    [0:9];

    integer i, k, cls, expected;
    integer pooled [0:PIXEL_NUM-1];
    integer sum    [0:9];

    function integer max4(input integer a, input integer b, input integer c, input integer d);
        integer m;
        begin
            m = a;
            if (b > m) m = b;
            if (c > m) m = c;
            if (d > m) m = d;
            max4 = m;
        end
    endfunction

    initial begin
        {row0[0],  row1[0]}  = {8'd12, 8'd87};   {row0[1],  row1[1]}  = {8'd45, 8'd3};
        {row0[2],  row1[2]}  = {8'd67, 8'd128};  {row0[3],  row1[3]}  = {8'd23, 8'd49};
        {row0[4],  row1[4]}  = {8'd91, 8'd7};    {row0[5],  row1[5]}  = {8'd30, 8'd118};
        {row0[6],  row1[6]}  = {8'd5,  8'd96};   {row0[7],  row1[7]}  = {8'd77, 8'd34};
        {row0[8],  row1[8]}  = {8'd50, 8'd20};   {row0[9],  row1[9]}  = {8'd16, 8'd104};
        {row0[10], row1[10]} = {8'd63, 8'd11};   {row0[11], row1[11]} = {8'd8,  8'd55};
        {row0[12], row1[12]} = {8'd38, 8'd65};   {row0[13], row1[13]} = {8'd99, 8'd14};
        {row0[14], row1[14]} = {8'd1,  8'd124};  {row0[15], row1[15]} = {8'd41, 8'd90};
        {row0[16], row1[16]} = {8'd26, 8'd72};   {row0[17], row1[17]} = {8'd85, 8'd37};
        {row0[18], row1[18]} = {8'd0,  8'd66};   {row0[19], row1[19]} = {8'd73, 8'd27};
        {row0[20], row1[20]} = {8'd53, 8'd18};   {row0[21], row1[21]} = {8'd17, 8'd100};
        {row0[22], row1[22]} = {8'd79, 8'd2};    {row0[23], row1[23]} = {8'd34, 8'd108};
        w[0] = 91; w[1] = -14; w[2] = -128; w[3] = 77;   w[4] = -63;
        w[5] = 32; w[6] = 0;   w[7] = 119;  w[8] = -101; w[9] = 45;

        // reference: pool each 2x2 block, accumulate per class, take the first maximum
        for (k = 0; k < PIXEL_NUM; k = k + 1)
            pooled[k] = max4(row0[2*k], row0[2*k+1], row1[2*k], row1[2*k+1]);
        expected = 0;
        for (cls = 0; cls < 10; cls = cls + 1) begin
            sum[cls] = 0;
            for (k = 0; k < PIXEL_NUM; k = k + 1)
                sum[cls] = sum[cls] + pooled[k] * w[cls];
            if (sum[cls] > sum[expected])
                expected = cls;
        end

        resetn   = 1'b0;
        valid_in = 1'b0;
        px_row0  = 0;
        px_row1  = 0;
        {weight_0, weight_1, weight_2, weight_3, weight_4} = {w[0], w[1], w[2], w[3], w[4]};
        {weight_5, weight_6, weight_7, weight_8, weight_9} = {w[5], w[6], w[7], w[8], w[9]};

        #20 resetn = 1'b1;
        #10;

        // feed the two rows, one column per clock
        for (i = 0; i < 24; i = i + 1) begin
            @(posedge clk);
            valid_in = 1'b1;
            px_row0  = row0[i];
            px_row1  = row1[i];
        end
        @(posedge clk);
        valid_in = 1'b0;

        wait (argmax_valid == 1'b1);
        @(posedge clk);

        $display("argmax_out = %0d, expected %0d", argmax_out, expected);
        $display("class sums: %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                 sum[0], sum[1], sum[2], sum[3], sum[4], sum[5], sum[6], sum[7], sum[8], sum[9]);
        if (argmax_out == expected)
            $display("PASS: MaxPool -> FC -> ArgMax returned class %0d", argmax_out);
        else
            $display("FAIL: MaxPool -> FC -> ArgMax returned class %0d, expected %0d",
                     argmax_out, expected);

        #20;
        $finish;
    end

endmodule
