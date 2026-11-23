`timescale 1ns / 1ps

// Testbench for the Sobel controller on its own: the input image (vectors/fake_image.hex) is served
// as BRAM1 with one cycle of read latency, and every write the controller makes to BRAM2 is logged
// and counted. When done rises the controller must have written all 10,000 output pixels.
//
// VECTOR_DIR is resolved against the simulator's working directory; tools/run_sims.py copies
// vectors/ there. Override it with -d VECTOR_DIR=<path> if needed.
`ifndef VECTOR_DIR
  `define VECTOR_DIR "vectors"
`endif

module tb_memory_ctrlr;

    reg         clk;
    reg         resetn;
    reg         start;

    wire [13:0] bram1_addr;
    reg  [7:0]  bram1_data;
    wire [13:0] bram2_addr;
    wire [7:0]  bram2_data;
    wire        bram2_we;
    wire        done;

    reg  [7:0]  image [0:102*102-1];
    reg  [15:0] write_count = 0;

    memory_ctrlr dut (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .s1_en(),
        .s1_we(),
        .s1_addr(bram1_addr),
        .s1_dout(bram1_data),
        .s2_en(),
        .s2_we(bram2_we),
        .s2_addr(bram2_addr),
        .s2_din(bram2_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk        = 0;
        resetn     = 0;
        start      = 0;
        bram1_data = 0;
        #20 resetn = 1;

        $readmemh({`VECTOR_DIR, "/fake_image.hex"}, image);
        #20 start = 1;
        #10 start = 0;
    end

    always @(posedge clk) begin
        // serve BRAM1 with one cycle of read latency
        bram1_data <= image[bram1_addr];

        if (bram2_we) begin
            $display("write %0d: %0d", bram2_addr, bram2_data);
            write_count <= write_count + 1;
        end

        if (done) begin
            if (write_count == 10000)
                $display("PASS: controller wrote all 10000 output pixels");
            else
                $display("FAIL: controller wrote %0d output pixels, expected 10000", write_count);
            $finish;
        end
    end

endmodule
