`timescale 1ns / 1ps

// Behavioral model of the Block Memory Generator core: a 16,384 x 8-bit single-port RAM with an
// enable pin and one clock cycle of read latency in write-first mode, without output registers.
// The core's .xci file was not kept, so this model stands in for it. It follows Vivado's RAM
// inference template, so the same file simulates in xsim and synthesizes to block RAM.
module bram (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [13:0] addra,
    input  wire [7:0]  dina,
    output reg  [7:0]  douta
);

    reg [7:0] mem [0:16383];

    initial douta = 8'd0;

    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) begin
                mem[addra] <= dina;
                douta      <= dina;
            end else begin
                douta <= mem[addra];
            end
        end
    end

endmodule
