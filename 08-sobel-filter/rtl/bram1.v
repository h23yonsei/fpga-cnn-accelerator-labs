`timescale 1ns / 1ps

// Behavioral model of the course's Block Memory Generator core BRAM1 (input image): a
// 16,384 x 8-bit true dual-port RAM with one clock cycle of write-first read latency on both ports.
// The core's .xci file was not kept, so this model stands in for it. It follows Vivado's RAM
// inference template, so the same file simulates in xsim and synthesizes to block RAM.
module bram1 (
    input  wire        clka,
    input  wire        ena,
    input  wire [0:0]  wea,
    input  wire [13:0] addra,
    input  wire [7:0]  dina,
    output reg  [7:0]  douta,
    input  wire        clkb,
    input  wire        enb,
    input  wire [0:0]  web,
    input  wire [13:0] addrb,
    input  wire [7:0]  dinb,
    output reg  [7:0]  doutb
);

    reg [7:0] mem [0:16383];

    initial begin
        douta = 8'd0;
        doutb = 8'd0;
    end

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

    always @(posedge clkb) begin
        if (enb) begin
            if (web[0]) begin
                mem[addrb] <= dinb;
                doutb      <= dinb;
            end else begin
                doutb <= mem[addrb];
            end
        end
    end

endmodule
