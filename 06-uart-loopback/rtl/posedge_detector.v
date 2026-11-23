`timescale 1ns / 1ps

// Rising-edge detector: pulse is high while sig is high and was low on the previous clock edge.
module posedge_detector (
    input  wire clk,
    input  wire rst,
    input  wire sig,
    output wire pulse
);

    reg sig_q;

    always @(posedge clk or posedge rst) begin
        if (rst)
            sig_q <= 1'b0;
        else
            sig_q <= sig;
    end

    assign pulse = sig && (sig_q ^ sig);

endmodule
