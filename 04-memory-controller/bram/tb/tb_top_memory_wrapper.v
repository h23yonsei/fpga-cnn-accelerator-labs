`timescale 1ns / 1ps

// Testbench for the block-RAM running-sum controller. Two copies of the design run side by side:
// one RAM starts with the course's initialize_memory.hex, the other with random data
// (random_memory.hex). After a reset and a start pulse the testbench waits for both to finish, then
// reads all 256 entries of each back through the external read port and compares them with the
// expected running sums (answer_memory.hex, random_answer.hex; all four files are written by
// tools/gen_vectors.py). Every entry of the course data is 0x0001, so only the random RAM can tell
// a correct read from a stale one.
//
// Stimulus changes on the falling clock edge and outputs are sampled just after the rising edge, so
// the result does not depend on how a simulator orders events at a clock edge.
//
// VECTOR_DIR is resolved against the simulator's working directory; tools/run_sims.py copies
// vectors/ there. Override it with -d VECTOR_DIR=<path> if needed.
`ifndef VECTOR_DIR
  `define VECTOR_DIR "vectors"
`endif

module tb_top_memory_wrapper;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg         resetn = 1'b1;
    reg         start  = 1'b0;
    reg         ext_enb   = 1'b0;
    reg  [7:0]  ext_addrb = 8'd0;
    wire        done_course, done_random;
    wire [15:0] doutb_course, doutb_random;

    reg  [15:0] expected_course [0:255];
    reg  [15:0] expected_random [0:255];

    top_memory_wrapper #(.INIT_FILE({`VECTOR_DIR, "/initialize_memory.hex"})) dut_course (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done_course),
        .ext_enb(ext_enb),
        .ext_addrb(ext_addrb),
        .ext_doutb(doutb_course)
    );

    top_memory_wrapper #(.INIT_FILE({`VECTOR_DIR, "/random_memory.hex"})) dut_random (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done_random),
        .ext_enb(ext_enb),
        .ext_addrb(ext_addrb),
        .ext_doutb(doutb_random)
    );

    integer k;
    integer errors = 0;

    // Reads entry k of both RAMs: the address is presented before a rising edge, and the data is on
    // doutb after the RAM's two cycles of read latency.
    initial begin
        $readmemh({`VECTOR_DIR, "/answer_memory.hex"}, expected_course);
        $readmemh({`VECTOR_DIR, "/random_answer.hex"}, expected_random);

        repeat (3) @(negedge clk);
        resetn = 1'b0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        repeat (2) @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        wait (done_course && done_random);
        for (k = 0; k < 256; k = k + 1) begin
            @(negedge clk);
            ext_enb   = 1'b1;
            ext_addrb = k;
            @(posedge clk);
            @(posedge clk);
            #1;
            if (doutb_course !== expected_course[k]) begin
                if (errors < 5)
                    $display("    course data, entry %0d: expected %h, got %h",
                             k, expected_course[k], doutb_course);
                errors = errors + 1;
            end
            if (doutb_random !== expected_random[k]) begin
                if (errors < 5)
                    $display("    random data, entry %0d: expected %h, got %h",
                             k, expected_random[k], doutb_random);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: memory comparison succeeded at %0t ns for the course data and random data",
                     $time);
        else
            $display("FAIL: memory comparison failed, %0d of 512 entries wrong", errors);
        $finish;
    end

    // safety net in case done never rises
    initial begin
        #300_000;
        $display("FAIL: timed out waiting for done at %0t ns", $time);
        $finish;
    end

endmodule
