`timescale 1ns / 1ps

// Behavioral model of the Block Memory Generator core sram_conv2_result: true dual port,
// 1024 x 24-bit with a write enable per byte, one-cycle read-first read on both ports, outputs
// power up at 0. The course project instantiated the core, but its .xci was not kept; this model
// reproduces the geometry and read latency the RTL expects. It follows Vivado's RAM inference
// templates, so it simulates in xsim and synthesizes to block RAM.
module sram_conv2_result (
    input  wire        clka,
    input  wire        ena,
    input  wire [2:0]  wea,
    input  wire [9:0]  addra,
    input  wire [23:0] dina,
    output reg  [23:0] douta,
    input  wire        clkb,
    input  wire        enb,
    input  wire [2:0]  web,
    input  wire [9:0]  addrb,
    input  wire [23:0] dinb,
    output reg  [23:0] doutb
);

    reg [23:0] mem [0:1023];

    integer ia, ib;

    initial begin
        douta = 0;
        doutb = 0;
    end

    always @(posedge clka) begin
        if (ena) begin
            for (ia = 0; ia < 3; ia = ia + 1)
                if (wea[ia])
                    mem[addra][8*ia +: 8] <= dina[8*ia +: 8];
            douta <= mem[addra];
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            for (ib = 0; ib < 3; ib = ib + 1)
                if (web[ib])
                    mem[addrb][8*ib +: 8] <= dinb[8*ib +: 8];
            doutb <= mem[addrb];
        end
    end

endmodule
