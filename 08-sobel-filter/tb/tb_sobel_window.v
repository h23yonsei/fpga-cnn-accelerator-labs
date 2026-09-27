`timescale 1ns / 1ps

// Testbench for the Sobel window. Random pixel columns are shifted into the 3x3 window, and every
// output flagged result_valid is compared with |Gx| + |Gy| (saturated to 255) computed here over
// the window of the previous cycle, since sobel_window registers its gradient sums. Stimulus
// changes on the falling edge so the DUT samples stable data.
module tb_sobel_window;

    localparam DATA_WIDTH = 8;
    localparam VECTORS    = 200;

    reg                   clk;
    reg                   resetn;
    reg                   ready;
    reg  [DATA_WIDTH-1:0] data_in0;
    reg  [DATA_WIDTH-1:0] data_in1;
    reg  [DATA_WIDTH-1:0] data_in2;
    wire [DATA_WIDTH-1:0] edge_out;
    wire                  valid;
    wire                  result_valid;

    integer errors   = 0;
    integer checks   = 0;
    integer prev_ref = 0;

    always #5 clk = ~clk;

    sobel_window #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .data_in0(data_in0),
        .data_in1(data_in1),
        .data_in2(data_in2),
        .ready(ready),
        .edge_out(edge_out),
        .valid(valid),
        .result_valid(result_valid)
    );

    // reference window, shifted like sobel_window: column 2 is the newest sample
    integer win [0:2][0:2];
    integer r, c;

    function integer sobel_ref(input integer unused);
        integer gx, gy, s;
        begin
            gx = -win[0][0] + win[0][2] - 2*win[1][0] + 2*win[1][2] - win[2][0] + win[2][2];
            gy = -win[0][0] - 2*win[0][1] - win[0][2] + win[2][0] + 2*win[2][1] + win[2][2];
            s  = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
            sobel_ref = (s > 255) ? 255 : s;
        end
    endfunction

    always @(posedge clk) begin
        if (resetn && ready) begin
            for (r = 0; r < 3; r = r + 1) begin
                win[r][0] = win[r][1];
                win[r][1] = win[r][2];
            end
            win[0][2] = data_in0;
            win[1][2] = data_in1;
            win[2][2] = data_in2;
        end
        #1;
        if (resetn && result_valid) begin
            checks = checks + 1;
            if (edge_out !== prev_ref) begin
                errors = errors + 1;
                $display("MISMATCH at %0t: edge_out=%0d, expected %0d", $time, edge_out, prev_ref);
            end
        end
        prev_ref = sobel_ref(0);    // this cycle's window, checked on the next cycle
    end

    initial begin
        for (r = 0; r < 3; r = r + 1)
            for (c = 0; c < 3; c = c + 1)
                win[r][c] = 0;

        clk      = 0;
        resetn   = 0;
        ready    = 0;
        data_in0 = 0;
        data_in1 = 0;
        data_in2 = 0;

        #15 resetn = 1;

        // drive a new random column on each falling edge while ready is high
        @(negedge clk);
        ready = 1;
        repeat (VECTORS) begin
            data_in0 = $random;
            data_in1 = $random;
            data_in2 = $random;
            @(negedge clk);
        end

        ready = 0;
        #50;
        if (errors == 0 && checks > 0)
            $display("PASS: Sobel window matched the reference on %0d outputs", checks);
        else
            $display("FAIL: %0d of %0d Sobel outputs mismatched", errors, checks);
        $finish;
    end

endmodule
