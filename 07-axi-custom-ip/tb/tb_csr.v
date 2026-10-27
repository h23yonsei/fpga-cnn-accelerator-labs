`timescale 1ns / 1ps

// Testbench for the csr IP through its AXI4-Lite interface, the way the PS drives it.
//
// Checks: after reset both registers read 0; each write of 1 to register 1 produces exactly one
// one-cycle start pulse, after which bit 0 of register 1 reads back 0 again (the restore logic);
// writing 0 produces no pulse; and register 0 bit 0 follows done.
module tb_csr;

    localparam ADDR_WIDTH = 4;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg                   aresetn = 1'b0;
    reg                   done    = 1'b0;
    wire                  start;

    reg  [ADDR_WIDTH-1:0] awaddr  = 0;
    reg                   awvalid = 1'b0;
    wire                  awready;
    reg  [31:0]           wdata   = 32'd0;
    reg                   wvalid  = 1'b0;
    wire                  wready;
    wire [1:0]            bresp;
    wire                  bvalid;
    reg                   bready  = 1'b1;
    reg  [ADDR_WIDTH-1:0] araddr  = 0;
    reg                   arvalid = 1'b0;
    wire                  arready;
    wire [31:0]           rdata;
    wire [1:0]            rresp;
    wire                  rvalid;
    reg                   rready  = 1'b1;

    csr_v1_0 dut (
        .start(start),
        .done(done),
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr(awaddr),
        .s00_axi_awprot(3'b000),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata),
        .s00_axi_wstrb(4'hF),
        .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bresp(bresp),
        .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready),
        .s00_axi_araddr(araddr),
        .s00_axi_arprot(3'b000),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready)
    );

    integer errors = 0;
    integer pulses = 0;
    reg     hs;
    reg     start_d = 1'b0;
    reg [31:0] value;

    // count start pulses; a pulse must last exactly one cycle
    always @(posedge clk) begin
        start_d <= start;
        if (start)
            pulses = pulses + 1;
        if (start && start_d) begin
            errors = errors + 1;
            $display("MISMATCH: start high for more than one cycle at %0t ns", $time);
        end
    end

    // AXI4-Lite write of one register; inputs change on the falling edge
    task axi_write(input integer index, input [31:0] data);
        begin
            @(negedge clk);
            awaddr = index * 4; awvalid = 1'b1;
            wdata  = data;      wvalid  = 1'b1;
            hs = 1'b0;
            while (!hs) begin
                @(negedge clk);
                hs = awready && wready;
            end
            @(negedge clk);
            awvalid = 1'b0; wvalid = 1'b0;
            while (!bvalid) @(negedge clk);
            @(negedge clk);
        end
    endtask

    // AXI4-Lite read of one register
    task axi_read(input integer index, output [31:0] data);
        begin
            @(negedge clk);
            araddr = index * 4; arvalid = 1'b1;
            hs = 1'b0;
            while (!hs) begin
                @(negedge clk);
                hs = arready;
            end
            @(negedge clk);
            arvalid = 1'b0;
            while (!rvalid) @(negedge clk);
            data = rdata;
            @(negedge clk);
        end
    endtask

    task expect_reg(input integer index, input [31:0] exp, input [8*40-1:0] what);
        begin
            axi_read(index, value);
            if (value !== exp) begin
                errors = errors + 1;
                $display("MISMATCH %0s: register %0d = %h, expected %h", what, index, value, exp);
            end else begin
                $display("ok  %0s: register %0d = %h", what, index, value);
            end
        end
    endtask

    task expect_pulses(input integer exp, input [8*40-1:0] what);
        begin
            repeat (10) @(negedge clk);
            if (pulses !== exp) begin
                errors = errors + 1;
                $display("MISMATCH %0s: %0d start pulses, expected %0d", what, pulses, exp);
            end else begin
                $display("ok  %0s: %0d start pulses", what, pulses);
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        aresetn = 1'b1;

        expect_reg(0, 32'd0, "after reset");
        expect_reg(1, 32'd0, "after reset");
        expect_pulses(0, "no start after reset");

        axi_write(1, 32'd1);
        expect_pulses(1, "write 1 to register 1");
        expect_reg(1, 32'd0, "start bit restored");

        done = 1'b1;
        expect_reg(0, 32'd1, "done high");
        axi_write(1, 32'd1);
        expect_pulses(2, "second write of 1");
        expect_reg(1, 32'd0, "start bit restored again");
        done = 1'b0;
        expect_reg(0, 32'd0, "done low");

        axi_write(1, 32'd0);
        expect_pulses(2, "write 0 to register 1");

        if (errors == 0)
            $display("PASS: csr starts once per write of 1 and restores the start bit");
        else
            $display("FAIL: %0d csr checks failed", errors);
        $finish;
    end

endmodule
