`timescale 1ns / 1ps

// Testbench for the memory controller IP, using the course's test data. It plays the role of the PS
// software: write 1..256 into sram1 through port A, pulse start, wait for done, then read the 192
// words the controller packed into sram2 back through port A and compare them with the course's
// answer file (vectors/answer_memory.hex). Block RAM reads on port A have one cycle of latency.
`ifndef VECTOR_DIR
  `define VECTOR_DIR "vectors"
`endif

module tb_top_memory_ctrlr;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg         resetn = 1'b0;
    reg         start  = 1'b0;
    wire        done;

    reg         s1_ena   = 1'b0;
    reg  [1:0]  s1_wea   = 2'b00;
    reg  [7:0]  s1_addra = 8'd0;
    reg  [15:0] s1_dina  = 16'd0;
    wire [15:0] s1_douta;

    reg         s2_ena   = 1'b0;
    reg  [3:0]  s2_wea   = 4'b0000;
    reg  [7:0]  s2_addra = 8'd0;
    reg  [31:0] s2_dina  = 32'd0;
    wire [31:0] s2_douta;

    reg [15:0] init_mem [0:255];
    reg [31:0] answer   [0:191];
    integer    i;
    integer    errors = 0;

    top_memory_ctrlr dut (
        .clk(clk), .resetn(resetn), .start(start), .done(done),
        .s1_clka(clk), .s1_ena(s1_ena), .s1_wea(s1_wea),
        .s1_addra(s1_addra), .s1_dina(s1_dina), .s1_douta(s1_douta),
        .s2_clka(clk), .s2_ena(s2_ena), .s2_wea(s2_wea),
        .s2_addra(s2_addra), .s2_dina(s2_dina), .s2_douta(s2_douta)
    );

    initial begin
        #10_000_000;
        $display("FAIL: timeout waiting for done");
        $finish;
    end

    initial begin
        $readmemh({`VECTOR_DIR, "/init_memory.hex"}, init_mem);
        $readmemh({`VECTOR_DIR, "/answer_memory.hex"}, answer);

        repeat (3) @(posedge clk);
        #1 resetn = 1'b1;

        // PS writes the input into sram1
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            #1 s1_ena = 1'b1; s1_wea = 2'b11; s1_addra = i; s1_dina = init_mem[i];
        end
        @(posedge clk);
        #1 s1_ena = 1'b0; s1_wea = 2'b00;

        // start the controller and wait for done
        @(posedge clk);
        #1 start = 1'b1;
        @(posedge clk);
        #1 start = 1'b0;
        wait (done === 1'b1);
        @(posedge clk);

        // PS reads sram2 back
        for (i = 0; i < 192; i = i + 1) begin
            #1 s2_ena = 1'b1; s2_addra = i;
            @(posedge clk);
            #1;
            if (s2_douta !== answer[i]) begin
                errors = errors + 1;
                if (errors <= 5)
                    $display("MISMATCH sram2[%0d] = %h, expected %h", i, s2_douta, answer[i]);
            end
        end

        if (errors == 0)
            $display("PASS: sram2 matches the course answer for all 192 words");
        else
            $display("FAIL: %0d of 192 sram2 words differ from the course answer", errors);
        $finish;
    end

endmodule
