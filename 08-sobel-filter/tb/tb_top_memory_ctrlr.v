`timescale 1ns / 1ps

// Testbench for the complete Sobel filter IP, driven the way the PS drives it: the 102x102 test
// image (vectors/fake_image.hex) is written into BRAM1 through port A, the filter is started, and
// once done rises all 10,000 output pixels are read back from BRAM2 through port A (one cycle of
// read latency) and compared with the |Gx| + |Gy| reference image (vectors/sobel_expected.hex).
//
// VECTOR_DIR is resolved against the simulator's working directory; tools/run_sims.py copies
// vectors/ there. Override it with -d VECTOR_DIR=<path> if needed.
`ifndef VECTOR_DIR
  `define VECTOR_DIR "vectors"
`endif

module tb_top_memory_ctrlr;

    reg         clk = 1'b0;
    reg         resetn;
    reg         start;
    wire        done;

    reg         s1_ena;
    reg         s1_wea;
    reg  [13:0] s1_addra;
    reg  [7:0]  s1_dina;
    wire [7:0]  s1_douta;

    reg         s2_ena;
    reg         s2_wea;
    reg  [13:0] s2_addra;
    reg  [7:0]  s2_dina;
    wire [7:0]  s2_douta;

    reg  [7:0]  image    [0:10403];
    reg  [7:0]  expected [0:9999];

    integer i;
    integer errors = 0;

    always #5 clk = ~clk;

    top_memory_ctrlr dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .s1_clka(clk),
        .s1_ena(s1_ena),
        .s1_wea(s1_wea),
        .s1_addra(s1_addra),
        .s1_dina(s1_dina),
        .s1_douta(s1_douta),
        .s2_clka(clk),
        .s2_ena(s2_ena),
        .s2_wea(s2_wea),
        .s2_addra(s2_addra),
        .s2_dina(s2_dina),
        .s2_douta(s2_douta)
    );

    initial begin
        $readmemh({`VECTOR_DIR, "/fake_image.hex"}, image);
        $readmemh({`VECTOR_DIR, "/sobel_expected.hex"}, expected);
        resetn   = 0;
        start    = 0;
        s1_ena   = 0;
        s1_wea   = 0;
        s2_ena   = 0;
        s2_wea   = 0;
        s1_addra = 0;
        s2_addra = 0;
        s1_dina  = 0;
        s2_dina  = 0;

        #20 resetn = 1;

        // write the 102x102 image into BRAM1
        @(posedge clk);
        for (i = 0; i < 10404; i = i + 1) begin
            @(posedge clk);
            s1_ena   <= 1;
            s1_wea   <= 1;
            s1_addra <= i;
            s1_dina  <= image[i];
        end
        @(posedge clk);
        s1_ena <= 0;
        s1_wea <= 0;

        // start the filter and wait for it to finish
        @(posedge clk);
        start <= 1;
        @(posedge clk);
        start <= 0;
        wait (done == 1);

        // read the 100x100 edge image back from BRAM2 and compare it with the reference
        @(posedge clk);
        for (i = 0; i < 10000; i = i + 1) begin
            #1 s2_ena = 1; s2_addra = i;
            @(posedge clk);
            #1;
            if (s2_douta !== expected[i]) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("MISMATCH pixel %0d (row %0d, column %0d): got %0d, expected %0d",
                             i, i / 100, i % 100, s2_douta, expected[i]);
            end
        end
        s2_ena = 0;

        if (errors == 0)
            $display("PASS: all 10000 output pixels match the reference edge image");
        else
            $display("FAIL: %0d of 10000 output pixels differ from the reference edge image", errors);
        $finish;
    end

endmodule
